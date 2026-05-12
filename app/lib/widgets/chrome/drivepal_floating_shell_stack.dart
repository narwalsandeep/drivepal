import 'package:flutter/material.dart';

/// Full-bleed [navigationShell] with optional **top** / **bottom** floating chrome.
///
/// Bump [topOverlap] / [tabBarOverlap] into [MediaQuery] so scrollables and
/// [SafeArea] clear the islands while maps stay visible underneath.
class DrivepalFloatingShellStack extends StatelessWidget {
  const DrivepalFloatingShellStack({
    super.key,
    required this.navigationShell,
    required this.tabBarOverlap,
    this.topOverlap = 0,
    required this.bottomOverlay,
    this.chatFab,
  });

  final Widget navigationShell;

  /// [DrivepalFancyBottomNav.reservedOuterHeight].
  final double tabBarOverlap;

  /// [DrivepalFloatingTopBar.overlapBelowSafeTop] when using [DrivepalFloatingTopBar].
  final double topOverlap;

  final Widget bottomOverlay;

  final Widget? chatFab;

  @override
  Widget build(BuildContext context) {
    final m = MediaQuery.of(context);
    final bumpedBottom = m.padding.bottom + tabBarOverlap;
    final bumpedViewBottom = m.viewPadding.bottom + tabBarOverlap;
    final bumpedTop = m.padding.top + topOverlap;
    final bumpedViewTop = m.viewPadding.top + topOverlap;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        MediaQuery(
          data: m.copyWith(
            padding: EdgeInsets.fromLTRB(
              m.padding.left,
              bumpedTop,
              m.padding.right,
              bumpedBottom,
            ),
            viewPadding: EdgeInsets.fromLTRB(
              m.viewPadding.left,
              bumpedViewTop,
              m.viewPadding.right,
              bumpedViewBottom,
            ),
          ),
          child: navigationShell,
        ),
        if (chatFab != null)
          Positioned(
            right: 16,
            bottom: tabBarOverlap + 12,
            child: chatFab!,
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: bottomOverlay,
        ),
      ],
    );
  }
}
