import 'drivepal_tokens.dart';

/// Shared layout metrics — keep in sync with `ui/src/styles/drivepal/tokens.css`.
abstract final class DrivepalLayout {
  /// `--drivepal-control-height` (`3.25rem` ≈ 52px).
  static const double controlHeight = 52;

  /// Radii are defined on [DrivepalTokens] (single source with CSS `--drivepal-radius-*`).
  static double get radiusInput => DrivepalTokens.radiusInput;

  static double get radiusCard => DrivepalTokens.radiusCard;

  static double get radiusButton => DrivepalTokens.radiusButton;
}
