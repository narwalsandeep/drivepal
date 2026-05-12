import 'package:flutter/material.dart';

import 'drivepal_tokens.dart';

/// Layered shadows for circular primary CTAs (booking “Go”, shell chat FAB).
abstract final class DrivepalCircularPrimaryShadow {
  /// Active “Go”-style halo + drop shadow.
  static List<BoxShadow> get layered => [
        BoxShadow(
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: 0,
          color: Colors.black.withValues(alpha: 0.22),
        ),
        BoxShadow(
          offset: const Offset(0, 4),
          blurRadius: 14,
          spreadRadius: 0,
          color: DrivepalTokens.bgPrimary.withValues(alpha: 0.45),
        ),
      ];

  /// Muted shadow when control is inactive.
  static List<BoxShadow> get subdued => [
        BoxShadow(
          offset: const Offset(0, 4),
          blurRadius: 10,
          color: Colors.black.withValues(alpha: 0.1),
        ),
      ];
}
