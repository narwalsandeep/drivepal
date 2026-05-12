import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/booking_map_defaults.dart';
import 'booking_map_fallback.dart';
import 'google_maps_embed_supported.dart';

/// Full-bleed Google Map for the booking flow.
///
/// Keys come from **`GOOGLE_MAPS_API_KEY`** in the repo-root **`.env`**:
/// — **Android:** read at Gradle build from **`../../.env`**
/// — **iOS:** **`$(GOOGLE_MAPS_API_KEY)`** via **`Flutter/*.xcconfig`**, optional override in
///   **`GoogleMapsEnv.local.xcconfig`** (run **`dart run tool/sync_google_maps_from_env.dart`**)
/// — **Web:** **`assets/google_maps_platform.env`** (same sync) + injected Maps JS in **`main`**.
///
/// **Linux / Windows / macOS:** `google_maps_flutter` has no desktop embed—the UI uses
/// [BookingMapFallback]; use an Android emulator, iOS simulator, or **Chrome (`-d chrome`)** to
/// preview the live map.
class BookingMapBackground extends StatelessWidget {
  const BookingMapBackground({super.key});

  static const _desktopCaption =
      'Live Google Maps runs on Android, iOS, and web. On Linux desktop, use Chrome (flutter run -d chrome) or a device emulator to preview the map.';

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
      initialCameraPosition: BookingMapDefaults.initialCamera,
      mapType: MapType.normal,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      liteModeEnabled: false,
      padding: EdgeInsets.zero,
    );
  }
}
