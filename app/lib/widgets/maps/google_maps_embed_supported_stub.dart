import 'package:flutter/foundation.dart' show kIsWeb;

/// Web uses the JS-backed implementation (no dart:io).
bool googleMapsEmbedSupported() => kIsWeb;
