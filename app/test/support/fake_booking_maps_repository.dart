import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:drivepal_app/config/booking_map_defaults.dart';
import 'package:drivepal_app/services/booking_maps_repository.dart';

/// Deterministic coords + route segments for booking widget tests.
class FakeBookingMapsRepository implements BookingMapsRepository {
  @override
  Future<BookingGeocodeResult?> geocode(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final h = q.hashCode;
    const base = BookingMapDefaults.defaultCenter;
    return BookingGeocodeResult(
      latLng: LatLng(
        base.latitude + (h % 500) * 1e-5 - 0.0025,
        base.longitude + (h.abs() % 500) * 1e-5 - 0.0025,
      ),
      formattedAddress: q,
    );
  }

  @override
  Future<BookingGeocodeResult?> reverseGeocode(LatLng latLng) async {
    return BookingGeocodeResult(
      latLng: latLng,
      formattedAddress: 'Current location, Test City',
    );
  }

  @override
  Future<BookingRouteResult> directions(
    LatLng origin,
    LatLng destination,
  ) async {
    final points = [
      origin,
      LatLng(
        (origin.latitude + destination.latitude) / 2,
        (origin.longitude + destination.longitude) / 2,
      ),
      destination,
    ];
    return BookingRouteResult(
      points: points,
      distanceMeters: 12400,
      durationSeconds: 1320,
      durationInTrafficSeconds: 1560,
    );
  }
}
