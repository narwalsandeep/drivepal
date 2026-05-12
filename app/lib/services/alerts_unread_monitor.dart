import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auth_session.dart';
import 'notifications_api.dart';

/// Foreground unread-alert monitor for customer shell badge state.
///
/// Polls notifications periodically while customer session is active, refreshes
/// once on app resume, and exposes a simple unread count for UI badges.
class AlertsUnreadMonitor extends ChangeNotifier with WidgetsBindingObserver {
  AlertsUnreadMonitor({
    NotificationsApi? notificationsApi,
    Duration? pollInterval,
  }) : _notificationsApi = notificationsApi ?? NotificationsApi(),
       _pollInterval = pollInterval ?? const Duration(seconds: 45);

  final NotificationsApi _notificationsApi;
  final Duration _pollInterval;

  AuthSession? _authSession;
  Timer? _pollTimer;
  bool _pollInFlight = false;
  bool _active = false;
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  void attachAuthSession(AuthSession authSession) {
    if (identical(_authSession, authSession)) {
      return;
    }
    _authSession?.removeListener(_onAuthChanged);
    _authSession = authSession;
    _authSession?.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void syncUnreadCount(int unreadCount) {
    final safeUnread = unreadCount < 0 ? 0 : unreadCount;
    if (_unreadCount == safeUnread) {
      return;
    }
    _unreadCount = safeUnread;
    notifyListeners();
  }

  Future<void> refreshNow() async {
    if (!_active) {
      return;
    }
    await _pollUnreadCount();
  }

  void _onAuthChanged() {
    final auth = _authSession;
    final shouldRun =
        auth != null && auth.isLoggedIn && auth.activeRole == 'customer';
    if (!shouldRun) {
      _stopMonitoring(resetUnread: true);
      return;
    }
    _startMonitoringIfNeeded();
  }

  void _startMonitoringIfNeeded() {
    if (_active) {
      return;
    }
    _active = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextPoll(immediate: true);
  }

  void _stopMonitoring({required bool resetUnread}) {
    if (_active) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (resetUnread) {
      syncUnreadCount(0);
    }
  }

  void _scheduleNextPoll({bool immediate = false}) {
    _pollTimer?.cancel();
    if (!_active) {
      return;
    }
    _pollTimer = Timer(
      immediate ? Duration.zero : _pollInterval,
      () => unawaited(_pollUnreadCount()),
    );
  }

  Future<void> _pollUnreadCount() async {
    if (_pollInFlight || !_active) {
      return;
    }
    _pollInFlight = true;
    try {
      final token = await _authSession?.getValidAccessToken();
      if (token == null) {
        syncUnreadCount(0);
        return;
      }
      final response = await _notificationsApi.listMine(
        bearerToken: token,
        unreadOnly: true,
        limit: 1,
      );
      syncUnreadCount(response.unreadCount);
    } catch (_) {
      // Keep last unread state on transient failures.
    } finally {
      _pollInFlight = false;
      _scheduleNextPoll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshNow());
    }
  }

  @override
  void dispose() {
    _authSession?.removeListener(_onAuthChanged);
    _stopMonitoring(resetUnread: false);
    super.dispose();
  }
}
