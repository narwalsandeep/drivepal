import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drivepal_app/screens/chat/chat_landing_screen.dart';
import 'package:drivepal_app/screens/change_password_screen.dart';
import 'package:drivepal_app/screens/app_settings_screen.dart';
import 'package:drivepal_app/screens/customer/book_ride_screen.dart';
import 'package:drivepal_app/screens/customer/alerts_screen.dart';
import 'package:drivepal_app/screens/customer/customer_shell_screen.dart';
import 'package:drivepal_app/screens/customer/payment_methods_screen.dart';
import 'package:drivepal_app/screens/customer/rider_profile_screen.dart';
import 'package:drivepal_app/screens/customer/rider_active_trip_screen.dart';
import 'package:drivepal_app/screens/customer/travel_history_screen.dart';
import 'package:drivepal_app/screens/edit_profile_screen.dart';
import 'package:drivepal_app/screens/driver/driver_new_requests_screen.dart';
import 'package:drivepal_app/screens/driver/driver_onboarding_screen.dart';
import 'package:drivepal_app/screens/driver/driver_cars_screen.dart';
import 'package:drivepal_app/screens/driver/driver_earnings_screen.dart';
import 'package:drivepal_app/screens/driver/driver_profile_edit_screen.dart';
import 'package:drivepal_app/screens/driver/driver_profile_screen.dart';
import 'package:drivepal_app/screens/driver/driver_shell_screen.dart';
import 'package:drivepal_app/screens/driver/driver_trips_screen.dart';
import 'package:drivepal_app/screens/forgot_screen.dart';
import 'package:drivepal_app/screens/home_screen.dart';
import 'package:drivepal_app/screens/login_screen.dart';
import 'package:drivepal_app/screens/menu_topic_screen.dart';
import 'package:drivepal_app/screens/reset_screen.dart';
import 'package:drivepal_app/screens/signup_screen.dart';
import 'package:drivepal_app/services/auth_session.dart';

final GlobalKey<NavigatorState> drivepalRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildDrivepalRouter(AuthSession auth) {
  return GoRouter(
    navigatorKey: drivepalRootNavigatorKey,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) {
      const authFlowPaths = <String>{
        '/login',
        '/signup',
        '/forgot-password',
        '/reset-password',
      };
      final loc = state.matchedLocation;
      final loggedIn = auth.isLoggedIn;

      if (!loggedIn &&
          (loc.startsWith('/customer') || loc.startsWith('/driver'))) {
        return '/login';
      }
      if (loggedIn &&
          auth.needsDriverOnboarding &&
          loc.startsWith('/driver') &&
          loc != '/driver/onboarding') {
        return '/driver/onboarding';
      }
      if (loggedIn && authFlowPaths.contains(loc)) {
        return auth.homeLocation;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return ResetScreen(kid: q['kid'] ?? '', code: q['code'] ?? '');
        },
      ),
      GoRoute(
        path: '/customer',
        redirect: (context, state) {
          if (state.uri.path == '/customer') {
            return '/customer/book';
          }
          return null;
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return CustomerShellScreen(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'book',
                    builder: (context, state) => const BookRideScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const TravelHistoryScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'alerts',
                    builder: (context, state) => const AlertsScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'account',
                    builder: (context, state) => const RiderProfileScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const ChatLandingScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'payment',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const PaymentMethodsScreen(),
          ),
          GoRoute(
            path: 'active-trip/:bookingId',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => RiderActiveTripScreen(
              bookingId: state.pathParameters['bookingId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'edit-profile',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const DriverProfileEditScreen(),
          ),
          GoRoute(
            path: 'change-password',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'settings',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder:
                (context, state) => const AppSettingsScreen(roleLabel: 'Rider'),
          ),
          GoRoute(
            path: 'menu/:topic',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) {
              return MenuTopicScreen(
                topic: state.pathParameters['topic'] ?? '',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/driver',
        redirect: (context, state) {
          if (state.uri.path == '/driver') {
            return '/driver/new';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: 'onboarding',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const DriverOnboardingScreen(),
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return DriverShellScreen(navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'new',
                    builder:
                        (context, state) => const DriverNewRequestsScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'trips',
                    builder: (context, state) => const DriverTripsScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'alerts',
                    builder: (context, state) => const AlertsScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const DriverProfileScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const ChatLandingScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'my-cars',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const DriverCarsScreen(),
          ),
          GoRoute(
            path: 'my-earning',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const DriverEarningsScreen(),
          ),
          GoRoute(
            path: 'edit-profile',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder:
                (context, state) =>
                    const AppSettingsScreen(roleLabel: 'Driver'),
          ),
          GoRoute(
            path: 'menu/:topic',
            parentNavigatorKey: drivepalRootNavigatorKey,
            builder: (context, state) {
              return MenuTopicScreen(
                topic: state.pathParameters['topic'] ?? '',
              );
            },
          ),
        ],
      ),
    ],
  );
}
