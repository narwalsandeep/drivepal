import 'dart:io' show Platform;

/// Embedded [GoogleMap] is only implemented for Android and iOS in this plugin.
bool googleMapsEmbedSupported() =>
    Platform.isAndroid || Platform.isIOS;
