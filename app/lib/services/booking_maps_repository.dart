import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/booking_map_defaults.dart';
import '../util/google_encoded_polyline.dart';
import 'api_base.dart';
import 'google_maps_api_key.dart';

class BookingGeocodeResult {
  const BookingGeocodeResult({
    required this.latLng,
    required this.formattedAddress,
  });

  final LatLng latLng;
  final String formattedAddress;
}

class BookingRouteResult {
  const BookingRouteResult({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
    this.durationInTrafficSeconds,
  });

  final List<LatLng> points;
  final int? distanceMeters;
  final int? durationSeconds;
  final int? durationInTrafficSeconds;
}

/// Remote geocode + directions for the rider booking wizard.
abstract interface class BookingMapsRepository {
  Future<BookingGeocodeResult?> geocode(String query);
  Future<BookingGeocodeResult?> reverseGeocode(LatLng latLng);

  /// Route polyline + distance/duration metadata in map order.
  Future<BookingRouteResult> directions(LatLng origin, LatLng destination);
}

class HttpBookingMapsRepository implements BookingMapsRepository {
  HttpBookingMapsRepository({String? apiKey, String? apiBase})
    : _key = apiKey ?? readGoogleMapsApiKey(),
      _apiBase = apiBase ?? defaultApiBase();

  final String? _key;
  final String _apiBase;

  @override
  Future<BookingGeocodeResult?> geocode(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final key = _key;
    if (key == null || key.isEmpty) {
      return _fallbackCoordinate(q);
    }

    final b = BookingMapDefaults.geocodeBiasBounds;
    final boundsParam =
        '${b.southwest.latitude},${b.southwest.longitude}|'
        '${b.northeast.latitude},${b.northeast.longitude}';
    final local = await _fetchGeocode(
      q,
      key,
      bounds: boundsParam,
      region: 'gb',
      reason: 'local-bias',
    );
    if (local != null) return local;

    // Retry globally when local bounds/region bias yields no hit.
    return _fetchGeocode(q, key, reason: 'global-retry');
  }

  @override
  Future<BookingGeocodeResult?> reverseGeocode(LatLng latLng) async {
    final key = _key;
    if (key == null || key.isEmpty) {
      return BookingGeocodeResult(
        latLng: latLng,
        formattedAddress: '${latLng.latitude}, ${latLng.longitude}',
      );
    }

    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '${latLng.latitude},${latLng.longitude}',
      'key': key,
      'language': 'en',
    });
    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      _debugLog('Reverse geocode transport error: $e');
      return null;
    }
    if (resp.statusCode != 200) {
      _debugLog('Reverse geocode HTTP ${resp.statusCode}');
      return null;
    }

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) return null;
    final status = data['status'] as String?;
    if (status != 'OK') {
      _debugLog(
        'Reverse geocode status=$status for ${latLng.latitude},${latLng.longitude}',
      );
      return null;
    }
    final results = data['results'];
    if (results is! List || results.isEmpty) return null;
    final top = results.first;
    if (top is! Map<String, dynamic>) return null;
    final formatted = top['formatted_address'] as String?;
    if (formatted == null || formatted.trim().isEmpty) return null;
    return BookingGeocodeResult(
      latLng: latLng,
      formattedAddress: formatted.trim(),
    );
  }

  @override
  Future<BookingRouteResult> directions(
    LatLng origin,
    LatLng destination,
  ) async {
    final proxied = await _fetchDirectionsViaApi(origin, destination);
    if (proxied != null) {
      return proxied;
    }

    final key = _key;
    if (key == null || key.isEmpty) {
      return _fallbackRoute(origin, destination);
    }

    final originSpec = '${origin.latitude},${origin.longitude}';
    final destSpec = '${destination.latitude},${destination.longitude}';
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': originSpec,
      'destination': destSpec,
      'key': key,
      'departure_time': 'now',
      'traffic_model': 'best_guess',
    });
    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (_) {
      return _fallbackRoute(origin, destination);
    }
    if (resp.statusCode != 200) return _fallbackRoute(origin, destination);

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) {
      return _fallbackRoute(origin, destination);
    }
    if (data['status'] != 'OK') return _fallbackRoute(origin, destination);
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      return _fallbackRoute(origin, destination);
    }
    final first = routes.first;
    if (first is! Map<String, dynamic>) {
      return _fallbackRoute(origin, destination);
    }
    final overview = first['overview_polyline'];
    if (overview is! Map<String, dynamic>) {
      return _fallbackRoute(origin, destination);
    }
    final points = overview['points'] as String?;
    if (points == null || points.isEmpty) {
      return _fallbackRoute(origin, destination);
    }
    final decoded = decodeGoogleEncodedPolyline(points);
    if (decoded.length < 2) return _fallbackRoute(origin, destination);

    int? distanceMeters;
    int? durationSeconds;
    int? durationInTrafficSeconds;
    final legs = first['legs'];
    if (legs is List && legs.isNotEmpty) {
      final leg0 = legs.first;
      if (leg0 is Map<String, dynamic>) {
        final distance = leg0['distance'];
        if (distance is Map<String, dynamic>) {
          distanceMeters = (distance['value'] as num?)?.toInt();
        }
        final duration = leg0['duration'];
        if (duration is Map<String, dynamic>) {
          durationSeconds = (duration['value'] as num?)?.toInt();
        }
        final durationTraffic = leg0['duration_in_traffic'];
        if (durationTraffic is Map<String, dynamic>) {
          durationInTrafficSeconds =
              (durationTraffic['value'] as num?)?.toInt();
        }
      }
    }

    return BookingRouteResult(
      points: decoded,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      durationInTrafficSeconds: durationInTrafficSeconds,
    );
  }

  Future<BookingRouteResult?> _fetchDirectionsViaApi(
    LatLng origin,
    LatLng destination,
  ) async {
    final uri = Uri.parse(
      '$_apiBase/api/bookings/route'
      '?originLat=${origin.latitude}'
      '&originLng=${origin.longitude}'
      '&destinationLat=${destination.latitude}'
      '&destinationLng=${destination.longitude}',
    );
    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      _debugLog('Route proxy transport error: $e');
      return null;
    }
    if (resp.statusCode >= 400) {
      _debugLog('Route proxy HTTP ${resp.statusCode}');
      return null;
    }

    final data = jsonDecode(resp.body.isEmpty ? '{}' : resp.body);
    if (data is! Map<String, dynamic>) return null;
    final route = data['route'];
    if (route is! Map<String, dynamic>) return null;
    final encodedPolyline = route['encodedPolyline'] as String?;
    if (encodedPolyline == null || encodedPolyline.isEmpty) return null;
    final points = decodeGoogleEncodedPolyline(encodedPolyline);
    if (points.length < 2) return null;

    return BookingRouteResult(
      points: points,
      distanceMeters: (route['distanceMeters'] as num?)?.toInt(),
      durationSeconds: (route['durationSeconds'] as num?)?.toInt(),
      durationInTrafficSeconds:
          (route['durationInTrafficSeconds'] as num?)?.toInt(),
    );
  }

  /// Offline / CI: small deterministic offset around default city centre.
  BookingGeocodeResult? _fallbackCoordinate(String q) {
    final h = q.hashCode;
    const base = BookingMapDefaults.defaultCenter;
    return BookingGeocodeResult(
      latLng: LatLng(
        base.latitude + (h % 1000) * 1e-5 - 0.005,
        base.longitude + (h.abs() % 1000) * 1e-5 - 0.005,
      ),
      formattedAddress: q,
    );
  }

  BookingRouteResult _fallbackRoute(LatLng origin, LatLng destination) {
    final distanceMeters = _haversineMeters(origin, destination).round();
    final durationSeconds = (distanceMeters / 11.11).round();
    return BookingRouteResult(
      points: [origin, destination],
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      durationInTrafficSeconds: null,
    );
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h =
        (1 - math.cos(dLat)) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLng)) / 2;
    final c = 2 * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
    return earthRadiusM * c;
  }

  double _degToRad(double deg) => deg * 0.017453292519943295;

  Future<BookingGeocodeResult?> _fetchGeocode(
    String query,
    String key, {
    String? bounds,
    String? region,
    required String reason,
  }) async {
    final params = <String, String>{
      'address': query,
      'key': key,
      'language': 'en',
    };
    if (bounds != null && bounds.isNotEmpty) {
      params['bounds'] = bounds;
    }
    if (region != null && region.isNotEmpty) {
      params['region'] = region;
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      params,
    );

    http.Response resp;
    try {
      resp = await http.get(uri);
    } catch (e) {
      _debugLog('Geocode transport error ($reason): $e');
      return null;
    }
    if (resp.statusCode != 200) {
      _debugLog('Geocode HTTP ${resp.statusCode} ($reason)');
      return null;
    }

    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) return null;
    final status = data['status'] as String?;
    if (status != 'OK') {
      _debugLog('Geocode status=$status ($reason) query="$query"');
      return null;
    }
    final results = data['results'];
    if (results is! List || results.isEmpty) return null;
    final top = results.first;
    if (top is! Map<String, dynamic>) return null;
    final geom = top['geometry'];
    if (geom is! Map<String, dynamic>) return null;
    final loc = geom['location'];
    if (loc is! Map<String, dynamic>) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final formatted = top['formatted_address'] as String? ?? query;

    return BookingGeocodeResult(
      latLng: LatLng(lat, lng),
      formattedAddress: formatted,
    );
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint('[BookingMapsRepository] $message');
      return true;
    }());
  }
}
