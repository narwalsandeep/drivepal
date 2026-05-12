import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivepal_app/widgets/drivepal_fancy_bottom_nav.dart';

void main() {
  testWidgets('renders unread dot for configured destination index', (
    tester,
  ) async {
    const destinations = <DrivepalFancyNavDestination>[
      DrivepalFancyNavDestination(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.directions_car_filled_rounded,
        label: 'Ride',
      ),
      DrivepalFancyNavDestination(
        icon: Icons.history_rounded,
        selectedIcon: Icons.route_rounded,
        label: 'Trips',
      ),
      DrivepalFancyNavDestination(
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        label: 'Wallet',
      ),
      DrivepalFancyNavDestination(
        icon: Icons.notifications_none_rounded,
        selectedIcon: Icons.notifications_active_rounded,
        label: 'Alerts',
      ),
      DrivepalFancyNavDestination(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Account',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrivepalFancyBottomNav(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            unreadDotIndexes: const <int>{3},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('drivepal-nav-unread-dot-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('drivepal-nav-unread-dot-0')), findsNothing);
  });
}
