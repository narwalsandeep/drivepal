import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'alerts_unread_monitor.dart';
import 'auth_session.dart';
import 'notifications_api.dart';
import 'push_firebase_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebaseForPush();
}

class PushNotificationManager extends ChangeNotifier {
  PushNotificationManager({
    NotificationsApi? notificationsApi,
    FirebaseMessaging? messaging,
  }) : _notificationsApi = notificationsApi ?? NotificationsApi(),
       _messaging = messaging;

  final NotificationsApi _notificationsApi;
  final FirebaseMessaging? _messaging;

  AuthSession? _auth;
  AlertsUnreadMonitor? _alertsUnreadMonitor;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _firebaseReady = false;
  bool _bootstrapTried = false;
  bool _authWasLoggedIn = false;
  String? _currentToken;
  String? _lastKnownBearerToken;

  static const String _platformAndroid = 'android';
  static const String _platformIos = 'ios';
  static const String _platformWeb = 'web';

  String? get _platform {
    if (kIsWeb) return _platformWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _platformIos;
      case TargetPlatform.android:
        return _platformAndroid;
      default:
        return null;
    }
  }

  bool get _pushEnabled =>
      const String.fromEnvironment('PUSH_ENABLED') == 'true';

  FirebaseMessaging get _messagingOrDefault =>
      _messaging ?? FirebaseMessaging.instance;

  void attach({
    required AuthSession auth,
    required AlertsUnreadMonitor alertsUnreadMonitor,
  }) {
    if (identical(_auth, auth) && identical(_alertsUnreadMonitor, alertsUnreadMonitor)) {
      return;
    }
    _auth?.removeListener(_onAuthChanged);
    _auth = auth;
    _alertsUnreadMonitor = alertsUnreadMonitor;
    _authWasLoggedIn = auth.isLoggedIn;
    _auth?.addListener(_onAuthChanged);
    unawaited(_initializeAndSync());
  }

  Future<void> _initializeAndSync() async {
    if (!_pushEnabled) return;
    if (!_bootstrapTried) {
      _bootstrapTried = true;
      _firebaseReady = await initializeFirebaseForPush();
      if (_firebaseReady) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        _onMessageSub = FirebaseMessaging.onMessage.listen(
          (RemoteMessage message) {
            _handleForegroundMessage(message);
          },
        );
        _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) {
            _handleNotificationTap(message);
          },
        );
        _onTokenRefreshSub = _messagingOrDefault.onTokenRefresh.listen(
          (token) => unawaited(_registerToken(token)),
        );
        final initialMessage = await _messagingOrDefault.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      }
    }
    if (_firebaseReady) {
      await _syncWithAuthState();
    }
  }

  Future<void> _syncWithAuthState() async {
    final auth = _auth;
    if (auth == null || !_pushEnabled || !_firebaseReady) {
      return;
    }
    if (!auth.isLoggedIn) {
      await _unregisterCurrentTokenIfNeeded();
      _authWasLoggedIn = false;
      _lastKnownBearerToken = null;
      return;
    }

    _authWasLoggedIn = true;
    final token = await _obtainPushToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(token);
  }

  Future<String?> _obtainPushToken() async {
    final messaging = _messagingOrDefault;
    await messaging.requestPermission();
    if (kIsWeb) {
      const vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');
      return messaging.getToken(
        vapidKey: vapidKey.trim().isEmpty ? null : vapidKey,
      );
    }
    return messaging.getToken();
  }

  Future<void> _registerToken(String token) async {
    final auth = _auth;
    final platform = _platform;
    if (auth == null || platform == null || !_firebaseReady || !_pushEnabled) {
      return;
    }
    final bearer = await auth.getValidAccessToken();
    if (bearer == null) return;
    _lastKnownBearerToken = bearer;
    try {
      await _notificationsApi.registerPushDevice(
        bearerToken: bearer,
        platform: platform,
        deviceToken: token,
        appVersion: const String.fromEnvironment('APP_VERSION').trim().isEmpty
            ? null
            : const String.fromEnvironment('APP_VERSION'),
        deviceLabel: kIsWeb ? 'web-browser' : defaultTargetPlatform.name,
      );
      _currentToken = token;
    } catch (_) {
      // Keep non-blocking; polling still provides fallback.
    }
  }

  Future<void> _unregisterCurrentTokenIfNeeded() async {
    final platform = _platform;
    final token = _currentToken;
    final bearer = _lastKnownBearerToken;
    if (platform == null || token == null || bearer == null) {
      _currentToken = null;
      return;
    }
    try {
      await _notificationsApi.unregisterPushDevice(
        bearerToken: bearer,
        platform: platform,
        deviceToken: token,
      );
    } catch (_) {
      // Ignore failures during logout transitions.
    } finally {
      _currentToken = null;
    }
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (auth == null) return;
    if (_authWasLoggedIn && !auth.isLoggedIn) {
      unawaited(_unregisterCurrentTokenIfNeeded());
    }
    _authWasLoggedIn = auth.isLoggedIn;
    unawaited(_initializeAndSync());
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final alertsMonitor = _alertsUnreadMonitor;
    if (alertsMonitor != null) {
      unawaited(alertsMonitor.refreshNow());
    }
    if (message.data.isNotEmpty) {
      _handleNotificationTap(message, foregroundOnly: true);
    }
  }

  void _handleNotificationTap(
    RemoteMessage message, {
    bool foregroundOnly = false,
  }) {
    final auth = _auth;
    if (auth == null || !auth.isLoggedIn) return;
    final bookingId = message.data['bookingId']?.toString();
    final role = auth.activeRole;
    final context = drivepalRootNavigatorKey.currentContext;
    if (context == null) return;
    final router = GoRouter.of(context);
    if (bookingId != null && bookingId.trim().isNotEmpty && role == 'customer') {
      router.go('/customer/active-trip/${bookingId.trim()}');
      return;
    }
    if (foregroundOnly) {
      return;
    }
    if (role == 'driver') {
      router.go('/driver/alerts');
    } else {
      router.go('/customer/alerts');
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _onTokenRefreshSub?.cancel();
    super.dispose();
  }
}
