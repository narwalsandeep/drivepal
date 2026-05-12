import 'package:flutter/material.dart';

import 'drivepal_tokens.dart';

/// Text styles shared by rider/driver shell chrome ([DrivepalFeatureIntroCard],
/// [DrivepalMapContextRibbon], elevated panels, empty states). No inline `.copyWith` in screens.
abstract final class DrivepalShellTypography {
  static TextStyle featureIntroTitle(TextTheme t) =>
      (t.titleLarge ?? const TextStyle(fontSize: 22)).copyWith(
        fontWeight: FontWeight.w700,
        color: DrivepalTokens.textHeading,
        letterSpacing: -0.35,
      );

  static TextStyle featureIntroSubtitle(TextTheme t) =>
      (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
        color: DrivepalTokens.textMuted,
        height: 1.35,
      );

  static TextStyle featureIntroBadge(TextTheme t) =>
      (t.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: DrivepalTokens.accentLink,
      );

  /// Gradient intro icon tile (square with rounded corners).
  static BoxDecoration introIconDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
      color: DrivepalTokens.bgPrimary.withValues(alpha: 0.12),
      border: Border.all(
        color: DrivepalTokens.bgPrimary.withValues(alpha: 0.2),
      ),
    );
  }

  /// Short strip above the booking route card (inside elevated surface).
  static TextStyle mapContextRibbonBody(TextTheme t) =>
      (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
        color: DrivepalTokens.textHeading,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: -0.12,
      );

  static TextStyle emptyStateTitle(TextTheme t) =>
      (t.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
        fontWeight: FontWeight.w700,
        color: DrivepalTokens.textHeading,
        letterSpacing: -0.2,
      );

  static TextStyle emptyStateBody(TextTheme t) =>
      (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
        color: DrivepalTokens.textMuted,
        height: 1.45,
      );

  /// Strong line inside [DrivepalElevatedPanel] (e.g. “No cards on file”).
  static TextStyle elevatedInlineTitle(TextTheme t) =>
      (t.titleSmall ?? const TextStyle(fontSize: 14)).copyWith(
        fontWeight: FontWeight.w600,
        color: DrivepalTokens.textHeading,
      );

  static TextStyle elevatedInlineBody(TextTheme t) =>
      (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
        color: DrivepalTokens.textMuted,
        height: 1.35,
      );

  /// Muted caption under primary actions (e.g. booking Go helper).
  static TextStyle primaryActionCaption(TextTheme t) =>
      (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
        color: DrivepalTokens.textMuted,
        height: 1.35,
      );

  /// Filled circular CTA label (Go).
  static const TextStyle goButtonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  );
}
