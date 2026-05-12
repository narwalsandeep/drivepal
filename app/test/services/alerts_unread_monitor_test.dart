import 'package:flutter_test/flutter_test.dart';
import 'package:drivepal_app/services/alerts_unread_monitor.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/notifications_api.dart';

class _FakeAuthSession extends AuthSession {
  bool loggedIn = true;
  String? role = 'customer';
  String? token = 'token';

  @override
  bool get isLoggedIn => loggedIn;

  @override
  String? get activeRole => role;

  @override
  Future<String?> getValidAccessToken() async => token;

  void setSession({
    required bool isLoggedIn,
    required String? activeRole,
    required String? accessToken,
  }) {
    loggedIn = isLoggedIn;
    role = activeRole;
    token = accessToken;
    notifyListeners();
  }
}

class _FakeNotificationsApi extends NotificationsApi {
  int unreadCount = 0;
  int listCalls = 0;

  @override
  Future<RiderNotificationsResponse> listMine({
    required String bearerToken,
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    listCalls++;
    return RiderNotificationsResponse(
      items: const <RiderNotificationItem>[],
      unreadCount: unreadCount,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshNow fetches unread count for active customer session', () async {
    final api = _FakeNotificationsApi()..unreadCount = 3;
    final auth = _FakeAuthSession();
    final monitor = AlertsUnreadMonitor(
      notificationsApi: api,
      pollInterval: const Duration(hours: 1),
    );
    monitor.attachAuthSession(auth);

    await monitor.refreshNow();

    expect(monitor.unreadCount, 3);
    expect(monitor.hasUnread, isTrue);
    expect(api.listCalls, greaterThan(0));
    monitor.dispose();
  });

  test('resets unread count when customer session ends', () async {
    final api = _FakeNotificationsApi()..unreadCount = 2;
    final auth = _FakeAuthSession();
    final monitor = AlertsUnreadMonitor(
      notificationsApi: api,
      pollInterval: const Duration(hours: 1),
    );
    monitor.attachAuthSession(auth);
    await monitor.refreshNow();
    expect(monitor.unreadCount, 2);

    auth.setSession(isLoggedIn: false, activeRole: null, accessToken: null);

    expect(monitor.unreadCount, 0);
    expect(monitor.hasUnread, isFalse);
    monitor.dispose();
  });
}
