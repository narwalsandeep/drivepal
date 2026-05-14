import 'dart:convert';

import 'package:drivepal_app/services/notifications_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NotificationsApi push device lifecycle', () {
    test('registerPushDevice sends expected payload', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'device': {'id': 'dev-1', 'platform': 'android', 'isActive': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = NotificationsApi(client: client, apiBase: 'http://localhost:3000');

      final res = await api.registerPushDevice(
        bearerToken: 'access-token',
        platform: 'android',
        deviceToken: 'device-token-very-long-value-123456789',
        appVersion: '1.0.0',
        deviceLabel: 'pixel',
      );

      expect(captured.url.path, '/api/notifications/devices/register');
      expect(captured.method, 'POST');
      expect(
        captured.headers['authorization'],
        'Bearer access-token',
      );
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['platform'], 'android');
      expect(body['deviceToken'], isNotEmpty);
      expect(res['device'], isNotNull);
    });

    test('unregisterPushDevice posts platform and token', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });
      final api = NotificationsApi(client: client, apiBase: 'http://localhost:3000');

      await api.unregisterPushDevice(
        bearerToken: 'access-token',
        platform: 'web',
        deviceToken: 'web-token-long-value-abcdefghijklmnopqrstuvwxyz',
      );

      expect(captured.url.path, '/api/notifications/devices/unregister');
      expect(captured.method, 'POST');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['platform'], 'web');
      expect(body['deviceToken'], isNotEmpty);
    });
  });
}
