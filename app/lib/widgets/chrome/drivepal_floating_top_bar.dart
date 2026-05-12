import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';

/// Rounded floating header (matches [DrivepalFancyBottomNav] island style).
class DrivepalFloatingTopBar extends StatelessWidget {
  const DrivepalFloatingTopBar({
    super.key,
    required this.onCogPressed,
    required this.onMenuSelected,
    this.tooltip = 'Settings',
    this.extraMenuItems = const <({String id, String label, IconData icon})>[],
  });

  final VoidCallback onCogPressed;
  final ValueChanged<String> onMenuSelected;
  final String tooltip;
  final List<({String id, String label, IconData icon})> extraMenuItems;

  static const double _gapAbove = 6;
  static const double _gapBelow = 6;
  static const double _contentClearanceBelow = 10;
  static const double _buttonSize = 44;
  static const _baseMenuItems = <({String id, String label, IconData icon})>[
    (
      id: 'help',
      label: 'Help center',
      icon: Icons.help_outline_rounded,
    ),
    (
      id: 'terms',
      label: 'Terms & conditions',
      icon: Icons.gavel_rounded,
    ),
    (
      id: 'privacy',
      label: 'Privacy policy',
      icon: Icons.privacy_tip_outlined,
    ),
    (
      id: 'contact',
      label: 'Contact us',
      icon: Icons.support_agent_rounded,
    ),
    (
      id: 'feedback',
      label: 'Feedback',
      icon: Icons.rate_review_outlined,
    ),
    (
      id: 'about',
      label: 'About app',
      icon: Icons.info_outline_rounded,
    ),
  ];

  /// Margin under the notch + toolbar row + clearance — add to existing
  /// [MediaQuery.padding]/[viewPadding] **top** (status bar is unchanged).
  static double overlapBelowSafeTop() {
    return _gapAbove + _buttonSize + _gapBelow + _contentClearanceBelow;
  }

  @override
  Widget build(BuildContext context) {
    final bg = DrivepalTokens.bgPrimary;
    final border = DrivepalTokens.bgPrimaryHover;
    final shadow = Colors.black.withValues(alpha: 0.28);

    return Align(
      alignment: Alignment.center,
      child: Row(
        children: [
          Material(
            color: bg,
            elevation: 4,
            shadowColor: shadow,
            surfaceTintColor: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: PopupMenuButton<String>(
              tooltip: 'Menu',
              onSelected: onMenuSelected,
              color: DrivepalTokens.bgCard,
              surfaceTintColor: Colors.transparent,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
                side: BorderSide(color: DrivepalTokens.borderCard),
              ),
              itemBuilder: (context) => [
                for (final item in <({String id, String label, IconData icon})>[
                  ..._baseMenuItems,
                  ...extraMenuItems,
                ])
                  PopupMenuItem<String>(
                    value: item.id,
                    child: Row(
                      children: [
                        Icon(item.icon, size: 19, color: DrivepalTokens.textHeading),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: DrivepalTokens.textHeading,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
              child: Ink(
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: DrivepalTokens.textOnPrimary,
                ),
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: bg,
            elevation: 4,
            shadowColor: shadow,
            surfaceTintColor: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: _buttonSize,
              height: _buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: IconButton(
                tooltip: tooltip,
                onPressed: onCogPressed,
                icon: const Icon(Icons.settings_rounded),
                color: DrivepalTokens.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
