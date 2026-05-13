import 'package:flutter/material.dart';

/// Semantic colors and design values mirrored from `ui/src/styles/drivepal/tokens.css`.
/// Use these for [ColorScheme] overrides and any widget that must match staff web
/// exactly. Prefer [Theme.of(context).colorScheme] when the mapping exists.
abstract final class DrivepalTokens {
  // ——— Brand / primary ———
  /// Single source for app brand hue; switch this to recolor primary accents.
  static const Color brandPrimary = Color(0xFF111111);

  /// `--drivepal-brand-seed`
  static const Color brandSeed = brandPrimary;

  /// Primary action color.
  static const Color bgPrimary = brandPrimary;

  /// Hover/pressed state for primary actions.
  static const Color bgPrimaryHover = Color(0xFF262626);

  // ——— Surfaces ———
  /// `--drivepal-bg-scaffold` (slate-50)
  static const Color bgScaffold = Color(0xFFF5F5F5);

  /// `--drivepal-bg-input` / `--drivepal-bg-card`
  static const Color bgInput = Color(0xFFFFFFFF);
  static const Color bgCard = Color(0xFFFFFFFF);

  /// Light strip behind auth card title row (slate-100) — Flutter-only.
  static const Color bgCardTitleBar = Color(0xFFEDEDED);

  /// `--drivepal-bg-overlay` — busy overlay (semi-transparent slate-50)
  static const Color bgOverlay = Color(0xEBF5F5F5);

  // ——— Borders ———
  /// `--drivepal-border-input` (slate-300)
  static const Color borderInput = Color(0xFFD1D1D1);

  /// `--drivepal-border-card` (slate-200)
  static const Color borderCard = Color(0xFFE1E1E1);

  /// `--drivepal-border-focus` (teal-500)
  static const Color borderFocus = brandPrimary;

  // ——— Typography ———
  /// `--drivepal-text-body` (slate-600) — general copy
  static const Color textBody = Color(0xFF4B5563);

  /// Typed text in fields & dense UI (slate-800) — darker than [textBody].
  static const Color textInput = Color(0xFF1F2937);

  /// `--drivepal-text-heading` (slate-900)
  static const Color textHeading = Color(0xFF111111);

  /// `--drivepal-text-muted` (slate-500)
  static const Color textMuted = Color(0xFF6B7280);

  /// `--drivepal-text-faint` (slate-400)
  static const Color textFaint = Color(0xFF9CA3AF);

  /// `--drivepal-text-on-primary`
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ——— Accents ———
  /// `--drivepal-accent-icon` (slate-400) — header / hint icons
  static const Color accentIcon = Color(0xFF9CA3AF);

  /// `--drivepal-accent-icon-soft` (slate-300) — general soft chrome
  static const Color accentIconSoft = Color(0xFFD1D5DB);

  /// Prefix/suffix icons inside text fields — same as [accentIcon] so they read on white.
  static const Color accentIconInput = accentIcon;

  /// `--drivepal-accent-link` (teal-600)
  static const Color accentLink = brandPrimary;

  // ——— Feedback ———
  /// Semantic danger base (red-600) for destructive and cancelled states.
  static const Color danger = Color(0xFFDC2626);

  /// Soft danger background for icon chips / subtle status surfaces.
  static const Color dangerSoftBg = Color(0xFFFEE2E2);

  /// Soft danger border for outlined destructive accents.
  static const Color dangerSoftBorder = Color(0xFFFCA5A5);

  /// `--drivepal-text-danger` compatibility alias.
  static const Color textDanger = danger;

  /// `--drivepal-text-info` (teal-600)
  static const Color textInfo = brandPrimary;

  // ——— Booking status semantics (Tailwind palette) ———
  static const Color statusRequested = Color(0xFFD97706); // amber-600
  static const Color statusRequestedSoftBg = Color(0xFFFEF3C7); // amber-100

  static const Color statusAccepted = Color(0xFF2563EB); // blue-600
  static const Color statusAcceptedSoftBg = Color(0xFFDBEAFE); // blue-100

  static const Color statusArriving = Color(0xFF7C3AED); // violet-600
  static const Color statusArrivingSoftBg = Color(0xFFEDE9FE); // violet-100

  static const Color statusInProgress = Color(0xFF0284C7); // sky-600
  static const Color statusInProgressSoftBg = Color(0xFFE0F2FE); // sky-100

  static const Color statusCompleted = Color(0xFF059669); // emerald-600
  static const Color statusCompletedSoftBg = Color(0xFFD1FAE5); // emerald-100

  // ——— Location semantics ———
  /// Pickup marker/icon color (neutral dark gray).
  static const Color locationPickup = Color(0xFF374151);

  /// Destination marker/icon color (green).
  static const Color locationDropoff = Color(0xFF16A34A);

  /// Current location marker/icon color (green).
  static const Color locationCurrent = locationDropoff;

  /// Soft surface for green location actions/chips.
  static const Color locationGreenSoftBg = Color(0xFFDCFCE7);

  /// Soft surface for neutral pickup actions/chips.
  static const Color locationPickupSoftBg = Color(0xFFF3F4F6);

  // ——— Spinner ———
  /// `--drivepal-spinner-track`
  static const Color spinnerTrack = Color(0xFFE5E7EB);

  /// `--drivepal-spinner-head`
  static const Color spinnerHead = brandPrimary;

  // ——— Radii (CSS rem × 16) ———

  /// Global corner radius for app boxes/cards/buttons/inputs.
  /// Keep circles as explicit [BoxShape.circle] or [CircleBorder].
  static const double radiusIsland = 8;

  /// Input and textarea radius.
  static const double radiusInput = 8;

  /// Card/info surface radius.
  static const double radiusCard = 8;

  /// Button radius.
  static const double radiusButton = 8;
}
