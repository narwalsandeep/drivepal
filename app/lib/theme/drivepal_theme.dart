import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'drivepal_layout.dart';
import 'drivepal_tokens.dart';

export 'drivepal_tokens.dart';

/// Web staff UI palette (`ui/src/styles/drivepal/tokens.css`). Used to build
/// [buildDrivepalTheme] — prefer [Theme.of(context).colorScheme] / [TextTheme] in UI.
abstract final class DrivepalBrand {
  /// Matches `--drivepal-brand-seed`.
  static const Color seed = DrivepalTokens.brandSeed;

  /// `--drivepal-bg-primary` (teal-600).
  static const Color primaryButton = DrivepalTokens.bgPrimary;

  /// `--drivepal-bg-primary-hover` (teal-500).
  static const Color primaryButtonHover = DrivepalTokens.bgPrimaryHover;

  /// `--drivepal-bg-scaffold` (slate-50).
  static const Color scaffold = DrivepalTokens.bgScaffold;

  /// `--drivepal-bg-input` (white) — field fill / idle segmented surface.
  static const Color surfaceLow = DrivepalTokens.bgInput;
}

/// Material 3 theme aligned with the Angular staff web UI (light slate + teal).
ThemeData buildDrivepalTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: DrivepalTokens.brandSeed,
    brightness: Brightness.light,
  ).copyWith(
    primary: DrivepalTokens.bgPrimary,
    onPrimary: DrivepalTokens.textOnPrimary,
    secondary: DrivepalTokens.bgPrimaryHover,
    onSecondary: DrivepalTokens.textOnPrimary,
    surface: DrivepalTokens.bgScaffold,
    onSurface: DrivepalTokens.textHeading,
    onSurfaceVariant: DrivepalTokens.textMuted,
    outline: DrivepalTokens.borderInput,
    outlineVariant: DrivepalTokens.borderCard,
    error: DrivepalTokens.textDanger,
    onError: DrivepalTokens.textOnPrimary,
    scrim: DrivepalTokens.textHeading,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: DrivepalTokens.bgScaffold,
    brightness: Brightness.light,
  );

  final textTheme =
      GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: DrivepalTokens.textBody,
        displayColor: DrivepalTokens.textHeading,
      ).copyWith(
        headlineSmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.25,
          color: DrivepalTokens.textHeading,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.25,
          color: DrivepalTokens.textHeading,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DrivepalTokens.textHeading,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: DrivepalTokens.textMuted,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: DrivepalTokens.textInput,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: DrivepalTokens.textInput,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: DrivepalTokens.textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1,
          color: DrivepalTokens.textOnPrimary,
        ),
      );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: DrivepalTokens.bgScaffold,
      foregroundColor: DrivepalTokens.textHeading,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: DrivepalTokens.bgCard,
      surfaceTintColor: Colors.transparent,
      shape: shape.copyWith(
        side: const BorderSide(color: DrivepalTokens.borderCard),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogTheme(
      shape: shape,
      backgroundColor: DrivepalTokens.bgCard,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: DrivepalTokens.borderCard,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DrivepalTokens.spinnerHead,
      circularTrackColor: DrivepalTokens.spinnerTrack,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size.fromHeight(DrivepalLayout.controlHeight),
        ),
        maximumSize: const WidgetStatePropertyAll(
          Size(double.infinity, DrivepalLayout.controlHeight),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusButton),
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return DrivepalTokens.bgPrimary.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return DrivepalTokens.bgPrimaryHover;
          }
          return DrivepalTokens.bgPrimary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return DrivepalTokens.textOnPrimary.withValues(alpha: 0.38);
          }
          return DrivepalTokens.textOnPrimary;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DrivepalTokens.textHeading,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        minimumSize: const Size.fromHeight(DrivepalLayout.controlHeight),
        fixedSize: Size(double.infinity, DrivepalLayout.controlHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusButton),
        ),
        side: const BorderSide(color: DrivepalTokens.borderInput),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size.fromHeight(DrivepalLayout.controlHeight),
        ),
        maximumSize: const WidgetStatePropertyAll(
          Size(double.infinity, DrivepalLayout.controlHeight),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DrivepalTokens.bgPrimary;
          }
          return DrivepalTokens.bgInput;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DrivepalTokens.textOnPrimary;
          }
          return DrivepalTokens.textMuted;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return DrivepalTokens.bgPrimary.withValues(alpha: 0.12);
          }
          return DrivepalTokens.textHeading.withValues(alpha: 0.06);
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DrivepalTokens.accentLink,
        textStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: false,
      constraints: const BoxConstraints(minHeight: DrivepalLayout.controlHeight),
      filled: true,
      fillColor: DrivepalTokens.bgInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        borderSide: const BorderSide(color: DrivepalTokens.borderInput),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        borderSide: const BorderSide(color: DrivepalTokens.borderInput),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        borderSide: const BorderSide(color: DrivepalTokens.borderFocus, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      labelStyle: textTheme.bodyLarge?.copyWith(
        color: DrivepalTokens.textMuted,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        final base = textTheme.bodyLarge!;
        return base.copyWith(
          color:
              states.contains(WidgetState.focused)
                  ? DrivepalTokens.accentLink
                  : DrivepalTokens.textInput,
          fontWeight: FontWeight.w500,
        );
      }),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: DrivepalTokens.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: DrivepalTokens.textMuted,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      prefixIconColor: DrivepalTokens.accentIconInput,
      suffixIconColor: DrivepalTokens.accentIconInput,
    ),
    iconTheme: const IconThemeData(
      color: DrivepalTokens.accentIconSoft,
      size: 22,
    ),
  );
}
