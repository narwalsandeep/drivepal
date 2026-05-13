import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/screens/customer/travel_history_screen.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/booking_api.dart';
import 'package:drivepal_app/services/customer_tab_refresh_notifier.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

class _FakeAuthSession extends AuthSession {
  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _FakeBookingApi extends BookingApi {
  _FakeBookingApi(this._bookings);

  final List<BookingHistoryItem> _bookings;

  @override
  Future<List<BookingHistoryItem>> fetchMyBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return _bookings;
  }
}

void main() {
  testWidgets('renders empty state when no trips returned', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<CustomerTabRefreshNotifier>(
            create: (_) => CustomerTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: TravelHistoryScreen(
              bookingApi: _FakeBookingApi(const <BookingHistoryItem>[]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No trips yet'), findsOneWidget);
  });

  testWidgets('renders latest trip details', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<CustomerTabRefreshNotifier>(
            create: (_) => CustomerTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: TravelHistoryScreen(
              bookingApi: _FakeBookingApi(const <BookingHistoryItem>[
                BookingHistoryItem(
                  id: '1',
                  status: 'requested',
                  pickupAddress: '10 Start Street',
                  dropoffAddress: 'Airport Terminal 2',
                  carTitle: 'City Sedan',
                  paymentMaskedNumber: '**** 1042',
                  distanceMeters: 12400,
                  durationSeconds: 1320,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 Start Street'), findsOneWidget);
    expect(find.text('Airport Terminal 2'), findsOneWidget);
    expect(find.textContaining('City Sedan'), findsOneWidget);
    expect(find.text('Waiting for driver'), findsOneWidget);
  });
}
