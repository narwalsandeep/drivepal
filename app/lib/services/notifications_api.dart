import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import 'auth_api.dart';

class RiderNotificationItem {
  const RiderNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  factory RiderNotificationItem.fromJson(Map<String, dynamic> json) {
    return RiderNotificationItem(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? 'general').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      readAt: DateTime.tryParse((json['readAt'] ?? '').toString()),
      metadata:
          json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : const <String, dynamic>{},
    );
  }
}

class RiderNotificationsResponse {
  const RiderNotificationsResponse({
    required this.items,
    required this.unreadCount,
  });

  final List<RiderNotificationItem> items;
  final int unreadCount;

  factory RiderNotificationsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['notifications'];
    final items =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (item) => RiderNotificationItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
            : const <RiderNotificationItem>[];
    return RiderNotificationsResponse(
      items: items,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class NotificationsApi {
  NotificationsApi({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? defaultApiBase();

  final http.Client _client;
  final String _apiBase;

  Uri _u(String path) => Uri.parse('$_apiBase/api/notifications$path');

  Map<String, String> _authHeaders(String bearerToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken',
  };

  Future<RiderNotificationsResponse> listMine({
    required String bearerToken,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    final query =
        unreadOnly ? '?limit=$safeLimit&unreadOnly=true' : '?limit=$safeLimit';
    final decoded = await _requestJson(
      () => _client.get(_u('/me$query'), headers: _authHeaders(bearerToken)),
    );
    if (decoded is! Map<String, dynamic>) {
      return const RiderNotificationsResponse(items: [], unreadCount: 0);
    }
    return RiderNotificationsResponse.fromJson(decoded);
  }

  Future<RiderNotificationsResponse> markRead({
    required String bearerToken,
    required String notificationId,
  }) async {
    await _requestJson(
      () => _client.patch(
        _u('/$notificationId/read'),
        headers: _authHeaders(bearerToken),
      ),
    );
    return listMine(bearerToken: bearerToken);
  }

  Future<Object?> _requestJson(Future<http.Response> Function() request) async {
    try {
      final res = await request();
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded;
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
