import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';

/// Layout + surfaces aligned with `ui/src/styles/drivepal/components.css` (auth pages).
/// Shared with [DrivepalNarrowContent] / landing so mobile shell and auth flows align.
/// Colors mirror CSS via [DrivepalTokens]; typography from [ThemeData].
abstract final class DrivepalAuthTokens {
  /// `.drivepal-page__inner` — `max-width: 28rem`
  static const double maxContentWidth = 448;

  /// Horizontal gutter for auth + marketing (same as [pagePadding] horizontal).
  static const double pageGutter = 16;

  /// Padding below [SafeArea] before the back row (all [DrivepalAuthPage]s).
  static const double authPageTopInset = 10;

  /// Default outer padding for [DrivepalAuthPage] (signup, sign-in, forgot password, etc.).
  static const EdgeInsets pageOuterAuth = EdgeInsets.fromLTRB(
    pageGutter,
    authPageTopInset,
    pageGutter,
    12,
  );

  /// Same as [pageOuterAuth] (legacy name).
  static const EdgeInsets pageOuterSignup = pageOuterAuth;

  /// Tighter card body for stacked forms (all auth flows).
  static const EdgeInsets authCardFormPadding =
      EdgeInsets.fromLTRB(16, 14, 16, 24);

  /// Same as [authCardFormPadding] (legacy name).
  static const EdgeInsets signupCardContentPadding = authCardFormPadding;

  /// `.drivepal-page` — `padding: 3rem 1rem` (legacy full-bleed auth; prefer [pageGutter] for H).
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 48, 16, 48);

  /// Vertical rhythm — landing + section gaps.
  static const double sectionGapSm = 12;
  static const double sectionGapMd = 16;
  static const double sectionGapLg = 36;

  /// Space after back link — `.drivepal-card` `margin-top: 2.5rem`
  static const double backLinkToCardGap = 40;

  /// `.drivepal-card` — `padding: 2rem`
  static const double cardPadding = 32;

  /// `.drivepal-form--tight` — `gap: 1rem`
  static const double formGap = 16;

  /// `.drivepal-card` — `--drivepal-radius-card`
  static double get cardRadius => DrivepalTokens.radiusCard;

  /// `.drivepal-muted-footer` — `margin-top: 1.5rem`
  static const double footerTopGap = 24;

  /// Card border / fill — same as [DrivepalTokens.borderCard] / [DrivepalTokens.bgCard].
  static const Color borderCard = DrivepalTokens.borderCard;
  static const Color cardBackground = DrivepalTokens.bgCard;

  /// Busy overlay — `--drivepal-bg-overlay`
  static const Color overlayScrim = DrivepalTokens.bgOverlay;
}
