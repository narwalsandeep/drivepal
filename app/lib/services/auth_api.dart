import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Calls Nest `/api/auth/*`.
///
/// **Web:** Uses the same host as the app page with port **3000** unless `API_BASE`
/// is set (`--dart-define=API_BASE=http://127.0.0.1:3000`). Ensures CORS Origin
/// matches hosting (e.g. `localhost` everywhere). **API must be reachable** or
/// you get “Failed to fetch”; start Nest (`cd api && npm run start:dev`) or Docker.
/// **Device/emulator:** pass `--dart-define=API_BASE=http://10.0.2.2:3000` etc.
class AuthApi {
  AuthApi({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? defaultApiBase();

  final http.Client _client;
  final String _apiBase;

  Uri _u(String path) => Uri.parse('$_apiBase/api/auth$path');

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    required String bearerToken,
  }) async {
    try {
      final res = await _client.patch(
        _u(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    try {
      final h = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };
      final res = await _client.post(
        _u(path),
        headers: h,
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }
}

String _formatError(Object? decoded, int code) {
  if (decoded is Map<String, dynamic>) {
    final m = decoded['message'];
    if (m is List) return m.map((e) => e.toString()).join(', ');
    if (m is String) return m;
  }
  return 'Request failed ($code)';
}

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
