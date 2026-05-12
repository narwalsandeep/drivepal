import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/screens/customer/alerts_screen.dart';
import 'package:drivepal_app/services/alerts_unread_monitor.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/customer_tab_refresh_notifier.dart';
import 'package:drivepal_app/services/notifications_api.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

class _FakeAuthSession extends AuthSession {
  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this._items);

  final List<RiderNotificationItem> _items;

  @override
  Future<RiderNotificationsResponse> listMine({
    required String bearerToken,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    final filtered =
        unreadOnly ? _items.where((item) => !item.isRead).toList() : _items;
    return RiderNotificationsResponse(
      items: filtered,
      unreadCount: _items.where((item) => !item.isRead).length,
    );
  }

  @override
  Future<RiderNotificationsResponse> markRead({
    required String bearerToken,
    required String notificationId,
  }) async {
    final idx = _items.indexWhere((item) => item.id == notificationId);
    if (idx >= 0) {
      _items[idx] = RiderNotificationItem(
        id: _items[idx].id,
        kind: _items[idx].kind,
        title: _items[idx].title,
        body: _items[idx].body,
        isRead: true,
        createdAt: _items[idx].createdAt,
        readAt: DateTime.now(),
        metadata: _items[idx].metadata,
      );
    }
    return listMine(bearerToken: bearerToken);
  }
}

void main() {
  testWidgets('renders alerts empty state', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<AlertsUnreadMonitor>(
            create: (_) => AlertsUnreadMonitor(),
          ),
          ChangeNotifierProvider<CustomerTabRefreshNotifier>(
            create: (_) => CustomerTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: AlertsScreen(
              notificationsApi: _FakeNotificationsApi(
                <RiderNotificationItem>[],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No alerts yet'), findsOneWidget);
  });

  testWidgets('renders and marks alert as read', (tester) async {
    final api = _FakeNotificationsApi(<RiderNotificationItem>[
      RiderNotificationItem(
        id: 'n1',
        kind: 'trip_requested',
        title: 'Ride requested',
        body: 'Driver search started',
        isRead: false,
        createdAt: DateTime.now(),
      ),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<AlertsUnreadMonitor>(
            create: (_) => AlertsUnreadMonitor(),
          ),
          ChangeNotifierProvider<CustomerTabRefreshNotifier>(
            create: (_) => CustomerTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(body: AlertsScreen(notificationsApi: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ride requested'), findsOneWidget);
    await tester.tap(find.text('Ride requested'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unread (0)'), findsOneWidget);
  });
}
