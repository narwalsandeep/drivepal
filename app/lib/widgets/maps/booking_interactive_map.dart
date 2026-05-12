import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/booking_map_defaults.dart';
import 'booking_map_fallback.dart';
import 'google_maps_embed_supported.dart';

typedef BookingMapControllerCallback = void Function(GoogleMapController c);

/// Booking map with **[markers]** / **[polylines]** driven by parent state.
///
/// Falls back to [BookingMapFallback] on unsupported embeds (desktop) or web
/// without a key — [onControllerReady] will not run.
class BookingInteractiveMap extends StatelessWidget {
  const BookingInteractiveMap({
    super.key,
    required this.markers,
    required this.polylines,
    this.onControllerReady,
    this.initialCameraPosition = BookingMapDefaults.initialCamera,
    this.padding = EdgeInsets.zero,
    this.interactive = true,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final BookingMapControllerCallback? onControllerReady;
  final CameraPosition initialCameraPosition;
  final EdgeInsets padding;
  final bool interactive;

  static const _desktopCaption =
      'Live Google Maps runs on Android, iOS, and web. On Linux desktop, use Chrome (flutter run -d chrome) or an emulator.';
  static const _hidePlacesMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    if (!googleMapsEmbedSupported()) {
      return const BookingMapFallback(caption: _desktopCaption);
    }

    if (kIsWeb) {
      final key = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
      if (key.isEmpty) {
        return const BookingMapFallback();
      }
    }

    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      markers: markers,
      polylines: polylines,
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      liteModeEnabled: false,
      style: _hidePlacesMapStyle,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      rotateGesturesEnabled: interactive,
      tiltGesturesEnabled: interactive,
      padding: padding,
      onMapCreated: (c) => onControllerReady?.call(c),
    );
  }
}
