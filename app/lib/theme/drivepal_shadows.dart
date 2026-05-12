import 'package:flutter/material.dart';

/// Elevation shadows — values aligned with `ui/src/styles/drivepal/tokens.css`.
abstract final class DrivepalShadows {
  /// Unfocused fields: border only from [ThemeData.inputDecorationTheme] (no lift).
  static const List<BoxShadow> soft = [];

  /// Filled primary buttons (paired with zero elevation in light theme).
  static const Color buttonAmbient = Color(0x14000000);

  /// Auth cards — `--drivepal-shadow-card` (slate, slightly stronger than CSS min).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 1),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x120F172A),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  /// Teal glow when a field is focused — subtle halo (lighter than previous mobile tune).
  static List<BoxShadow> inputFocus(Color teal) => [
    BoxShadow(
      color: teal.withValues(alpha: 0.10),
      offset: const Offset(0, 0),
      blurRadius: 4,
    ),
    BoxShadow(
      color: teal.withValues(alpha: 0.08),
      offset: const Offset(0, 1),
      blurRadius: 8,
    ),
  ];
}
