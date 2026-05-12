import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Default camera for the booking map (London). Geocoding updates the view.
abstract final class BookingMapDefaults {
  /// Central London — default until a resolved address pins the map elsewhere.
  static const LatLng defaultCenter = LatLng(51.5074, -0.1278);

  static const double defaultZoom = 12.8;

  /// Zoom when exactly one resolved stop is framed.
  static const double singlePinZoom = 14.5;

  static const CameraPosition initialCamera = CameraPosition(
    target: defaultCenter,
    zoom: defaultZoom,
  );

  /// Geocoding API viewport bias (~Greater London).
  ///
  /// Improves partial addresses (ambiguous globally) resolving near the rider app default.
  static LatLngBounds get geocodeBiasBounds => LatLngBounds(
        southwest: LatLng(
          defaultCenter.latitude - 0.38,
          defaultCenter.longitude - 0.52,
        ),
        northeast: LatLng(
          defaultCenter.latitude + 0.38,
          defaultCenter.longitude + 0.38,
        ),
      );

  /// Pause after typing stops before Geocoding API call.
  static const Duration geocodeIdleDebounce = Duration(milliseconds: 1500);

  /// Deterministic map point when Geocoding has no result (matches test fake / HTTP no-key path).
  static LatLng approximateLatLngForQuery(String query) {
    final q = query.trim();
    final h = q.hashCode;
    final base = defaultCenter;
    return LatLng(
      base.latitude + (h % 500) * 1e-5 - 0.0025,
      base.longitude + (h.abs() % 500) * 1e-5 - 0.0025,
    );
  }
}
