import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/screens/customer/rider_active_trip_screen.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/booking_api.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

class _FakeAuthSession extends AuthSession {
  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _FakeTrackingBookingApi extends BookingApi {
  _FakeTrackingBookingApi(this._responses);

  final List<BookingTrackingSnapshot> _responses;
  int _calls = 0;

  @override
  Future<BookingTrackingSnapshot> fetchTrackingForBooking({
    required String bookingId,
    required String bearerToken,
  }) async {
    final idx = _calls < _responses.length ? _calls : _responses.length - 1;
    _calls += 1;
    return _responses[idx];
  }
}

void main() {
  testWidgets('polls active trip tracking and updates status text', (
    tester,
  ) async {
    final api = _FakeTrackingBookingApi([
      const BookingTrackingSnapshot(
        booking: BookingHistoryItem(
          id: 'booking-1',
          status: 'requested',
          pickupAddress: '10 Start Street',
          dropoffAddress: 'Airport',
          carTitle: 'City Sedan',
          paymentMaskedNumber: '**** 1111',
          canCancel: true,
        ),
      ),
      const BookingTrackingSnapshot(
        booking: BookingHistoryItem(
          id: 'booking-1',
          status: 'driver_arriving',
          pickupAddress: '10 Start Street',
          dropoffAddress: 'Airport',
          carTitle: 'City Sedan',
          paymentMaskedNumber: '**** 1111',
          canCancel: true,
        ),
        driverLocation: BookingDriverLocation(
          latitude: 51.50,
          longitude: -0.11,
        ),
      ),
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: RiderActiveTripScreen(bookingId: 'booking-1', bookingApi: api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finding a driver'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Driver arriving'), findsOneWidget);
  });
}
