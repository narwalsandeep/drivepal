import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivepal_app/theme/drivepal_shell_typography.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

/// Ensures booking-related typography resolves against the Drivepal theme stack.
void main() {
  testWidgets('shell typography accessors return usable styles', (
    tester,
  ) async {
    ThemeData captured = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: LayoutBuilder(
          builder: (context, _) {
            captured = Theme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final t = captured.textTheme;
    final titleStyle = DrivepalShellTypography.featureIntroTitle(t);
    expect(titleStyle.fontWeight, FontWeight.w700);
    expect(titleStyle.color, isNotNull);

    expect(DrivepalShellTypography.mapContextRibbonBody(t).fontWeight, isNotNull);
    expect(DrivepalShellTypography.primaryActionCaption(t).color, isNotNull);
    expect(DrivepalShellTypography.goButtonLabel.fontWeight, FontWeight.w800);
  });
}
