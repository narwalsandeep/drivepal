import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/main.dart';
import 'package:drivepal_app/router.dart';
import 'package:drivepal_app/services/auth_session.dart';

void main() {
  testWidgets('Home shell renders', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final auth = AuthSession();
    // In tests, skip await auth.restore() — secure storage can hang headless.
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSession>.value(
        value: auth,
        child: DrivepalApp(router: buildDrivepalRouter(auth)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mobile shell'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
