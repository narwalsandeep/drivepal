import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth/drivepal_auth_tokens.dart';
import 'chrome/drivepal_floating_top_bar.dart';
import 'drivepal_fancy_bottom_nav.dart';

/// Padding for tab bodies under [DrivepalFloatingShellStack]: horizontal gutter plus
/// top/bottom from [MediaQuery] so content clears the floating top bar and bottom nav.
EdgeInsets drivepalFloatingShellBodyPadding(
  BuildContext context, {
  double extraTop = 0,
  double extraBottom = 0,
}) {
  final p = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    DrivepalAuthTokens.pageGutter,
    p.top + extraTop,
    DrivepalAuthTokens.pageGutter,
    p.bottom + extraBottom,
  );
}

/// Bottom inset for modal sheets so content clears keyboard + floating bottom nav.
///
/// Use in `showModalBottomSheet` paddings to avoid clipping behind the shell nav.
double drivepalModalBottomInset(
  BuildContext context, {
  double extra = 12,
  bool includeFloatingNav = true,
}) {
  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  final shellNavInset =
      includeFloatingNav
          ? DrivepalFancyBottomNav.reservedOuterHeight(context)
          : safeBottom;
  return math.max(keyboardInset, shellNavInset) + extra;
}

/// Top inset for modal sheets in floating-shell pages.
///
/// Keeps sheets below the floating top bar (menu/settings) with an extra gap.
double drivepalModalTopInset(
  BuildContext context, {
  double extra = 12,
  bool includeFloatingTopBar = true,
}) {
  final safeTop = MediaQuery.paddingOf(context).top;
  final topBarInset =
      includeFloatingTopBar ? DrivepalFloatingTopBar.overlapBelowSafeTop() : 0.0;
  return safeTop + topBarInset + extra;
}

/// Centers content at [DrivepalAuthTokens.maxContentWidth] with the standard horizontal
/// gutter — shared by landing and auth so columns line up.
class DrivepalNarrowContent extends StatelessWidget {
  const DrivepalNarrowContent({super.key, required this.child, this.padding});

  final Widget child;

  /// Defaults to symmetric horizontal [DrivepalAuthTokens.pageGutter].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DrivepalAuthTokens.maxContentWidth,
        ),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: DrivepalAuthTokens.pageGutter,
              ),
          child: child,
        ),
      ),
    );
  }
}
