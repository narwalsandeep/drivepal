import 'package:flutter/foundation.dart' show kIsWeb;

const String apiBaseDefine = String.fromEnvironment('API_BASE');

String defaultApiBase() {
  final trimmed = apiBaseDefine.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
  if (kIsWeb) {
    final b = Uri.base;
    if (b.hasScheme && b.host.isNotEmpty) {
      return '${b.scheme}://${b.host}:3000';
    }
    return 'http://localhost:3000';
  }
  return 'http://127.0.0.1:3000';
}
