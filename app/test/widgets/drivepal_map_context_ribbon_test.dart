import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivepal_app/theme/drivepal_app_shell_copy.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';
import 'package:drivepal_app/widgets/drivepal_tab_page_chrome.dart';

void main() {
  testWidgets('ribbon shows centralized copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DrivepalMapContextRibbon(
              body: DrivepalAppShellCopy.riderBookMapContextRibbonBody,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('pickup and destination'), findsWidgets);
    expect(
      find.text(DrivepalAppShellCopy.riderBookMapContextRibbonBody),
      findsOneWidget,
    );
  });

  testWidgets('ribbon custom semantics label merges for a11y', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: DrivepalMapContextRibbon(
            semanticsLabel: 'Trip stops summary',
            body: DrivepalAppShellCopy.riderBookMapContextRibbonBody,
          ),
        ),
      ),
    );

    final label =
        tester.getSemantics(find.byType(DrivepalMapContextRibbon)).label;
    expect(label, contains('Trip stops summary'));
  });
}
