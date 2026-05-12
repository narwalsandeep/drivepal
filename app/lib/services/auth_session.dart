import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'auth_api.dart';

/// Persists access + refresh tokens in platform secure storage (iOS Keychain &
/// Android EncryptedSharedPreferences). Survives app restarts until [logout].
///
/// Pair with Nest `POST /api/auth/refresh` to rotate short-lived access tokens.
class AuthSession extends ChangeNotifier {
  AuthSession({AuthApi? api, FlutterSecureStorage? storage})
    : _api = api ?? AuthApi(),
      _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _kAccess = 'drivepal_access_token';
  static const _kRefresh = 'drivepal_refresh_token';
  static const _kUser = 'drivepal_user_json';
  static const _kRole = 'drivepal_active_role';

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  String? _activeRole;

  /// Session is present (access may be expired until [restore] or [getValidAccessToken] refreshes).
  bool get isLoggedIn =>
      _accessToken != null && _refreshToken != null && _activeRole != null;

  bool get needsDriverOnboarding =>
      _activeRole == 'driver' && _user?['driverProfileCompleted'] != true;

  String get homeLocation {
    if (_activeRole == 'driver') {
      return needsDriverOnboarding ? '/driver/onboarding' : '/driver/new';
    }
    return '/customer/book';
  }

  Map<String, dynamic>? get user => _user;

  String? get activeRole => _activeRole;

  String? get accessToken => _accessToken;

  /// Call after [WidgetsFlutterBinding.ensureInitialized], before [runApp].
  Future<void> restore() async {
    try {
      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
      _activeRole = await _storage.read(key: _kRole);
      final u = await _storage.read(key: _kUser);
      if (u != null) {
        try {
          _user = jsonDecode(u) as Map<String, dynamic>;
        } catch (_) {
          _user = null;
        }
      }

      if (_accessToken == null ||
          _refreshToken == null ||
          _activeRole == null) {
        await _clearMemoryOnly();
        notifyListeners();
        return;
      }

      var accessExpired = true;
      try {
        accessExpired = JwtDecoder.isExpired(_accessToken!);
      } catch (_) {
        accessExpired = true;
      }

      if (accessExpired) {
        await _tryRefresh();
      }

      if (_accessToken != null) {
        try {
          if (JwtDecoder.isExpired(_accessToken!)) {
            await _clearAll();
          }
        } catch (_) {
          await _clearAll();
        }
      } else {
        await _clearAll();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AuthSession.restore: $e\n$st');
      }
      await _clearAll();
    }
    notifyListeners();
  }

  Future<void> _tryRefresh() async {
    final rt = _refreshToken;
    if (rt == null) return;
    try {
      final res = await _api.post('/refresh', {'refreshToken': rt});
      await _applyRefreshResponse(res);
    } catch (_) {
      await _clearAll();
    }
  }

  Future<void> _applyRefreshResponse(Map<String, dynamic> res) async {
    final at = res['accessToken'] as String?;
    final newRt = res['refreshToken'] as String?;
    if (at == null || newRt == null) {
      await _clearAll();
      return;
    }
    _accessToken = at;
    _refreshToken = newRt;
    if (res['user'] is Map) {
      _user = Map<String, dynamic>.from(res['user']! as Map);
      await _storage.write(key: _kUser, value: jsonEncode(_user));
    }
    await _storage.write(key: _kAccess, value: at);
    await _storage.write(key: _kRefresh, value: newRt);
  }

  /// After successful [POST /login/verify] or [POST /signup/verify].
  Future<void> signInFromAuthResponse(
    Map<String, dynamic> res,
    String role,
  ) async {
    final normalized = role == 'driver' ? 'driver' : 'customer';
    _activeRole = normalized;
    await _storage.write(key: _kRole, value: normalized);
    if (res['user'] is Map) {
      _user = Map<String, dynamic>.from(res['user']! as Map);
      await _storage.write(key: _kUser, value: jsonEncode(_user));
    }
    final at = res['accessToken'] as String?;
    final rt = res['refreshToken'] as String?;
    if (at == null || rt == null) return;
    _accessToken = at;
    _refreshToken = rt;
    await _storage.write(key: _kAccess, value: at);
    await _storage.write(key: _kRefresh, value: rt);
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearAll();
    notifyListeners();
  }

  Future<void> _clearMemoryOnly() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _activeRole = null;
  }

  Future<void> _clearAll() async {
    await _clearMemoryOnly();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

  /// Refresh if needed, then return a usable Bearer token for API calls.
  Future<String?> getValidAccessToken() async {
    if (!isLoggedIn) return null;
    try {
      if (JwtDecoder.isExpired(_accessToken!)) {
        await _tryRefresh();
      }
    } catch (_) {
      await _tryRefresh();
    }
    if (_accessToken == null || JwtDecoder.isExpired(_accessToken!)) {
      return null;
    }
    return _accessToken;
  }

  /// Persists name/email on the server and merges local profile-photo (base64) into stored user JSON.
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    bool clearProfilePhoto = false,
    String? profilePhotoBase64,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) {
      throw StateError('Not signed in');
    }

    final res = await _api.patch('/profile', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
    }, bearerToken: token);

    final u = res['user'];
    if (u is! Map) {
      throw StateError('Invalid profile response');
    }

    final merged = Map<String, dynamic>.from(u);
    if (clearProfilePhoto) {
      merged.remove('profilePhotoBase64');
    } else if (profilePhotoBase64 != null) {
      merged['profilePhotoBase64'] = profilePhotoBase64;
    } else if (_user != null && _user!.containsKey('profilePhotoBase64')) {
      merged['profilePhotoBase64'] = _user!['profilePhotoBase64'];
    }

    _user = merged;
    await _storage.write(key: _kUser, value: jsonEncode(_user));
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) {
      throw StateError('Not signed in');
    }
    await _api.patch('/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, bearerToken: token);
  }

  Future<void> updateDriverProfile({
    required String driverProfilePhotoBase64,
    required String driverAddress,
    required String driverLocationText,
    required int driverAge,
    required String driverGender,
    required String driverVisaStatus,
    required String driverDlImageBase64,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) {
      throw StateError('Not signed in');
    }
    final res = await _api.patch('/driver-profile', {
      'driverProfilePhotoBase64': driverProfilePhotoBase64,
      'driverAddress': driverAddress.trim(),
      'driverLocationText': driverLocationText.trim(),
      'driverAge': driverAge,
      'driverGender': driverGender,
      'driverVisaStatus': driverVisaStatus.trim(),
      'driverDlImageBase64': driverDlImageBase64,
    }, bearerToken: token);
    final u = res['user'];
    if (u is! Map) {
      throw StateError('Invalid driver profile response');
    }
    _user = Map<String, dynamic>.from(u);
    await _storage.write(key: _kUser, value: jsonEncode(_user));
    notifyListeners();
  }

  /// Background profile/session sync used by tab re-entry refresh.
  Future<void> reloadUserFromServer() async {
    if (!isLoggedIn) {
      return;
    }
    await _tryRefresh();
    notifyListeners();
  }
}
