import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Same key env as **`GOOGLE_MAPS_API_KEY`** in **`assets/google_maps_platform.env`**.
String? readGoogleMapsApiKey() {
  try {
    if (!dotenv.isInitialized) return null;
  } catch (_) {
    return null;
  }
  final k = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
  return (k == null || k.isEmpty) ? null : k;
}
