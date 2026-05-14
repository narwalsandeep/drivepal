import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

FirebaseOptions? _resolveFirebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
  const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  const androidClientId = String.fromEnvironment('FIREBASE_ANDROID_CLIENT_ID');
  const iosClientId = String.fromEnvironment('FIREBASE_IOS_CLIENT_ID');

  if (apiKey.trim().isEmpty ||
      appId.trim().isEmpty ||
      messagingSenderId.trim().isEmpty ||
      projectId.trim().isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    measurementId: measurementId.isEmpty ? null : measurementId,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
    androidClientId: androidClientId.isEmpty ? null : androidClientId,
    iosClientId: iosClientId.isEmpty ? null : iosClientId,
  );
}

Future<bool> initializeFirebaseForPush() async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }
  final options = _resolveFirebaseOptionsFromEnvironment();
  if (options == null) {
    return false;
  }
  try {
    await Firebase.initializeApp(options: options);
    return true;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase init skipped: $error');
    }
    return false;
  }
}
