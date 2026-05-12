import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/screens/change_password_screen.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

class _FakeAuthSession extends AuthSession {
  bool changeCalled = false;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changeCalled = true;
  }
}

void main() {
  testWidgets('submits change password form when valid', (tester) async {
    final auth = _FakeAuthSession();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSession>.value(
        value: auth,
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: const ChangePasswordScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'OldPassword123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewPassword123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'NewPassword123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(auth.changeCalled, isTrue);
  });
}
