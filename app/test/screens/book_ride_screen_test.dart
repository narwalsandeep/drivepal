import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivepal_app/screens/customer/book_ride_screen.dart';
import 'package:drivepal_app/services/booking_api.dart';
import 'package:drivepal_app/theme/drivepal_app_shell_copy.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

import '../support/fake_booking_maps_repository.dart';

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._carOptions);

  final List<BookingCarOption> _carOptions;

  @override
  Future<BookingCarOptionsResponse> fetchCarOptions({
    String? bearerToken,
  }) async {
    return BookingCarOptionsResponse(
      currencyCode: 'GBP',
      carOptions: _carOptions,
    );
  }
}

void main() {
  testWidgets('pickup step shows only pickup field and Next — no ribbon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: BookRideScreen(mapsRepository: FakeBookingMapsRepository()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(DrivepalAppShellCopy.riderBookPickupHint), findsOneWidget);
    expect(find.text(DrivepalAppShellCopy.riderBookDestinationHint), findsNothing);
    expect(
      find.text(DrivepalAppShellCopy.riderBookMapContextRibbonBody),
      findsNothing,
    );
    expect(
      find.text(DrivepalAppShellCopy.riderBookPickupCurrentLocationLabel),
      findsOneWidget,
    );
    expect(
      find.text(DrivepalAppShellCopy.riderBookNextButtonLabel),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    expect(find.text(DrivepalAppShellCopy.riderBookGoButtonLabel), findsNothing);
  });

  testWidgets('after geocode idle Next advances to drop-off field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: BookRideScreen(mapsRepository: FakeBookingMapsRepository()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Start Lane');
    await tester.pump(const Duration(seconds: 3));

    await tester.ensureVisible(
      find.text(DrivepalAppShellCopy.riderBookNextButtonLabel),
    );
    await tester.tap(find.text(DrivepalAppShellCopy.riderBookNextButtonLabel));
    await tester.pumpAndSettle();

    expect(find.text(DrivepalAppShellCopy.riderBookDestinationHint), findsWidgets);
    expect(find.text(DrivepalAppShellCopy.riderBookPickupHint), findsNothing);
  });

  testWidgets('wizard reaches review with summary and Select car', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: BookRideScreen(mapsRepository: FakeBookingMapsRepository()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123 Market St');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text(DrivepalAppShellCopy.riderBookNextButtonLabel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Airport Terminal 2');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text(DrivepalAppShellCopy.riderBookNextButtonLabel));
    await tester.pumpAndSettle();

    expect(find.text('Select car'), findsOneWidget);
    expect(find.text('123 Market St'), findsOneWidget);
    expect(find.text('Airport Terminal 2'), findsOneWidget);

    final pickupEditInkWell = tester.widget<InkWell>(
      find.byKey(const ValueKey('booking-review-edit-pickup')),
    );
    pickupEditInkWell.onTap?.call();
    await tester.pumpAndSettle();
    expect(find.text(DrivepalAppShellCopy.riderBookPickupHint), findsOneWidget);
  });

  testWidgets('car picker shows API driven price per km', (tester) async {
    final bookingApi = _FakeBookingApi(
      const <BookingCarOption>[
        BookingCarOption(
          id: 'sedan4',
          title: 'City Sedan',
          subtitle: 'Comfort ride for everyday trips',
          seats: 4,
          pricePerKmGbp: 1.55,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDrivepalTheme(),
        home: Scaffold(
          body: BookRideScreen(
            mapsRepository: FakeBookingMapsRepository(),
            bookingApi: bookingApi,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123 Market St');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text(DrivepalAppShellCopy.riderBookNextButtonLabel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Airport Terminal 2');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text(DrivepalAppShellCopy.riderBookNextButtonLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select car'));
    await tester.pumpAndSettle();

    expect(find.textContaining('£1.55/km'), findsOneWidget);
  });
}
