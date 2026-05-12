import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'platform/maps_inject.dart';
import 'router.dart';
import 'services/alerts_unread_monitor.dart';
import 'services/auth_session.dart';
import 'services/customer_tab_refresh_notifier.dart';
import 'services/driver_tab_refresh_notifier.dart';
import 'services/payment_methods_store.dart';
import 'theme/drivepal_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  if (!kIsWeb && stripePublishableKey.trim().isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey.trim();
    await Stripe.instance.applySettings();
  }
  try {
    await dotenv.load(fileName: 'assets/google_maps_platform.env');
  } catch (_) {}
  if (kIsWeb) {
    await injectGoogleMapsScriptForWeb();
  }
  final authSession = AuthSession();
  await authSession.restore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSession>.value(value: authSession),
        ChangeNotifierProxyProvider<AuthSession, AlertsUnreadMonitor>(
          create: (_) => AlertsUnreadMonitor(),
          update: (_, auth, monitor) {
            final resolved = monitor ?? AlertsUnreadMonitor();
            resolved.attachAuthSession(auth);
            return resolved;
          },
        ),
        ChangeNotifierProvider<PaymentMethodsStore>(
          create: (_) => PaymentMethodsStore(),
        ),
        ChangeNotifierProvider<CustomerTabRefreshNotifier>(
          create: (_) => CustomerTabRefreshNotifier(),
        ),
        ChangeNotifierProvider<DriverTabRefreshNotifier>(
          create: (_) => DriverTabRefreshNotifier(),
        ),
      ],
      child: DrivepalApp(router: buildDrivepalRouter(authSession)),
    ),
  );
}

class DrivepalApp extends StatelessWidget {
  const DrivepalApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DRIVEPAL',
      debugShowCheckedModeBanner: false,
      theme: buildDrivepalTheme(),
      routerConfig: router,
    );
  }
}
