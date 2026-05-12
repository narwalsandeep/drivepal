import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';
import 'package:drivepal_app/widgets/auth_loading_overlay.dart';

void main() {
  testWidgets('AuthLoadingOverlay shows message and blocks pointer when visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: AuthLoadingOverlay(
            visible: true,
            message: 'Sending verification code…',
            child: ListView(
              children: const [SizedBox(height: 8)],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sending verification code…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is AbsorbPointer && w.absorbing,
      ),
      findsOneWidget,
    );
  });

  testWidgets('AuthLoadingOverlay hides overlay when not visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: AuthLoadingOverlay(
            visible: false,
            message: 'Hidden',
            child: const Center(child: Text('Content')),
          ),
        ),
      ),
    );

    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
