import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/driver_tab_refresh_notifier.dart';
import '../../widgets/chrome/drivepal_floating_shell_stack.dart';
import '../../widgets/chrome/drivepal_floating_top_bar.dart';
import '../../widgets/drivepal_fancy_bottom_nav.dart';

/// Driver chrome: floating [DrivepalFancyBottomNav] over full-bleed tab bodies.
class DriverShellScreen extends StatelessWidget {
  const DriverShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _navDestinations = [
    DrivepalFancyNavDestination(
      icon: Icons.local_taxi_outlined,
      selectedIcon: Icons.local_taxi_rounded,
      label: 'New',
    ),
    DrivepalFancyNavDestination(
      icon: Icons.route_outlined,
      selectedIcon: Icons.route_rounded,
      label: 'Trips',
    ),
    DrivepalFancyNavDestination(
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      label: 'Alerts',
    ),
    DrivepalFancyNavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Account',
    ),
    DrivepalFancyNavDestination(
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_rounded,
      label: 'Chat',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = navigationShell.currentIndex;
    final overlap = DrivepalFancyBottomNav.reservedOuterHeight(context);

    final topOverlap = DrivepalFloatingTopBar.overlapBelowSafeTop();

    return Scaffold(
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          DrivepalFloatingShellStack(
            topOverlap: topOverlap,
            tabBarOverlap: overlap,
            navigationShell: navigationShell,
            chatFab: null,
            bottomOverlay: SafeArea(
              top: false,
              child: DrivepalFancyBottomNav(
                selectedIndex: idx,
                onDestinationSelected: (selectedIndex) {
                  context.read<DriverTabRefreshNotifier>().markTabSelected(
                    selectedIndex,
                  );
                  navigationShell.goBranch(
                    selectedIndex,
                    initialLocation: selectedIndex == idx,
                  );
                },
                destinations: _navDestinations,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: DrivepalFloatingTopBar(
                  onMenuSelected: (id) {
                    if (id == 'my-cars') {
                      context.push('/driver/my-cars');
                      return;
                    }
                    if (id == 'my-earning') {
                      context.push('/driver/my-earning');
                      return;
                    }
                    context.push('/driver/menu/$id');
                  },
                  extraMenuItems: const [
                    (
                      id: 'my-cars',
                      label: 'My Cars',
                      icon: Icons.directions_car_filled_rounded,
                    ),
                    (
                      id: 'my-earning',
                      label: 'My Earning',
                      icon: Icons.payments_rounded,
                    ),
                  ],
                  onCogPressed: () => context.push('/driver/settings'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
