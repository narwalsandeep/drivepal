import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivepal_app/theme/drivepal_theme.dart';
import 'package:drivepal_app/widgets/booking/drivepal_booking_route_panel.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: buildDrivepalTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  testWidgets('shows hint text for both lanes', (tester) async {
    final pickup = TextEditingController();
    final dropoff = TextEditingController();
    addTearDown(() {
      pickup.dispose();
      dropoff.dispose();
    });

    await tester.pumpWidget(
      wrap(
        DrivepalBookingRoutePanel(
          pickupController: pickup,
          dropoffController: dropoff,
          onFieldChanged: () {},
        ),
      ),
    );

    expect(find.text('Pickup location'), findsOneWidget);
    expect(find.text('Where to?'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('typing notifies parent', (tester) async {
    final pickup = TextEditingController();
    final dropoff = TextEditingController();
    addTearDown(() {
      pickup.dispose();
      dropoff.dispose();
    });

    var calls = 0;
    await tester.pumpWidget(
      wrap(
        DrivepalBookingRoutePanel(
          pickupController: pickup,
          dropoffController: dropoff,
          onFieldChanged: () => calls++,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '123 Main');
    expect(calls, greaterThanOrEqualTo(1));
    await tester.enterText(find.byType(TextField).last, '456 Oak');
    expect(calls, greaterThanOrEqualTo(2));
  });

  testWidgets('disable animations context still lays out dotted rail', (
    tester,
  ) async {
    final pickup = TextEditingController();
    final dropoff = TextEditingController();
    addTearDown(() {
      pickup.dispose();
      dropoff.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DrivepalBookingRoutePanel(
                pickupController: pickup,
                dropoffController: dropoff,
                onFieldChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
  });
}
