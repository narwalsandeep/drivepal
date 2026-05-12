// Web-only injector; uses dart:html until migrating to package:web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> injectGoogleMapsScriptForWeb() async {
  final raw = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
  if (raw == null || raw.isEmpty) return;

  if (html.document.querySelector('script[data-drivepal-google-maps="1"]') !=
      null) {
    return;
  }

  final completer = Completer<void>();
  final mapsUri = Uri.https('maps.googleapis.com', '/maps/api/js', {
    'key': raw,
    'libraries': 'geometry,marker',
    'loading': 'async',
    'v': 'weekly',
  });
  final script = html.ScriptElement()
    ..dataset['drivepalGoogleMaps'] = '1'
    ..async = true
    ..src = mapsUri.toString();

  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Google Maps script failed to load'));
    }
  });

  html.document.head!.append(script);

  try {
    await completer.future.timeout(const Duration(seconds: 20));
    await _waitForGoogleMapsReady();
  } on TimeoutException {
    // Maps may still initialize later; booking UI has a fallback.
  } on Object {
    // Non-fatal.
  }
}

Future<void> _waitForGoogleMapsReady() async {
  const pollEvery = Duration(milliseconds: 120);
  const maxWait = Duration(seconds: 8);
  final started = DateTime.now();
  while (DateTime.now().difference(started) < maxWait) {
    if (_hasGoogleMapTypeIds()) {
      return;
    }
    await Future<void>.delayed(pollEvery);
  }
}

bool _hasGoogleMapTypeIds() {
  final win = html.window;
  if (!js_util.hasProperty(win, 'google')) {
    return false;
  }
  final google = js_util.getProperty<Object?>(win, 'google');
  if (google == null || !js_util.hasProperty(google, 'maps')) {
    return false;
  }
  final maps = js_util.getProperty<Object?>(google, 'maps');
  if (maps == null || !js_util.hasProperty(maps, 'MapTypeId')) {
    return false;
  }
  final mapTypeId = js_util.getProperty<Object?>(maps, 'MapTypeId');
  return mapTypeId != null && js_util.hasProperty(mapTypeId, 'ROADMAP');
}
