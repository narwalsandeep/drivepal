import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';

/// One tab in [DrivepalFancyBottomNav]. [label] is for accessibility only (icons-only bar).
class DrivepalFancyNavDestination {
  const DrivepalFancyNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Icons-only bottom bar with larger circular selection discs.
class DrivepalFancyBottomNav extends StatelessWidget {
  const DrivepalFancyBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.unreadDotIndexes = const <int>{},
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DrivepalFancyNavDestination> destinations;
  final Set<int> unreadDotIndexes;

  static const _anim = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  /// Larger circular hit area for selected tab; [_barHeight] leaves vertical inset.
  static const double _iconDisc = 52;
  static const double _barHeight = 64;
  /// Space below the bar, above the home indicator / screen edge.
  static const double _bottomMargin = 14;

  /// Overlay layout: reserve this much bottom inset on [navigationShell].
  static double reservedOuterHeight(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return _barHeight + _bottomMargin + bottom;
  }

  @override
  Widget build(BuildContext context) {
    assert(destinations.isNotEmpty);
    final barBg = DrivepalTokens.bgPrimaryHover;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final shadow = Colors.black.withValues(alpha: 0.35);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, _bottomMargin + bottom),
      child: Material(
        color: barBg,
        elevation: 8,
        shadowColor: shadow,
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
          ),
          child: SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _FancyNavTile(
                      destination: destinations[i],
                      tabIndex: i,
                      selected: selectedIndex == i,
                      showUnreadDot: unreadDotIndexes.contains(i),
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FancyNavTile extends StatelessWidget {
  const _FancyNavTile({
    required this.destination,
    required this.tabIndex,
    required this.selected,
    required this.showUnreadDot,
    required this.onTap,
  });

  final DrivepalFancyNavDestination destination;
  final int tabIndex;
  final bool selected;
  final bool showUnreadDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveIcon = DrivepalTokens.textOnPrimary.withValues(alpha: 0.88);

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: destination.label,
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          splashColor: DrivepalTokens.bgPrimary.withValues(alpha: 0.15),
          highlightColor: DrivepalTokens.bgPrimary.withValues(alpha: 0.08),
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: DrivepalFancyBottomNav._anim,
                curve: DrivepalFancyBottomNav._curve,
                alignment: Alignment.center,
                width: DrivepalFancyBottomNav._iconDisc,
                height: DrivepalFancyBottomNav._iconDisc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? DrivepalTokens.bgCard : Colors.transparent,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 28,
                      color: selected ? DrivepalTokens.bgPrimary : inactiveIcon,
                    ),
                    if (showUnreadDot)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          key: ValueKey('drivepal-nav-unread-dot-$tabIndex'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: DrivepalTokens.textDanger,
                            border: Border.all(
                              width: 1.1,
                              color:
                                  selected
                                      ? DrivepalTokens.bgCard
                                      : DrivepalTokens.bgPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
