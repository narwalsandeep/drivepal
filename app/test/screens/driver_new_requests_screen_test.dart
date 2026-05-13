import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drivepal_app/screens/driver/driver_new_requests_screen.dart';
import 'package:drivepal_app/services/auth_api.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/booking_api.dart';
import 'package:drivepal_app/services/driver_tab_refresh_notifier.dart';
import 'package:drivepal_app/theme/drivepal_theme.dart';

class _FakeAuthSession extends AuthSession {
  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _FakeDriverBookingApi extends BookingApi {
  int updateLocationCalls = 0;

  @override
  Future<List<BookingHistoryItem>> fetchDriverOpenBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return const <BookingHistoryItem>[];
  }

  @override
  Future<List<BookingHistoryItem>> fetchDriverBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return const <BookingHistoryItem>[
      BookingHistoryItem(
        id: 'booking-driver-1',
        status: 'accepted',
        pickupAddress: '10 Start Street',
        dropoffAddress: 'Airport',
        carTitle: 'City Sedan',
        paymentMaskedNumber: '**** 1111',
      ),
    ];
  }

  @override
  Future<void> updateDriverLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required String bearerToken,
  }) async {
    updateLocationCalls += 1;
  }
}

class _FlakyDriverRequestFeedApi extends BookingApi {
  _FlakyDriverRequestFeedApi(this._openResponsesOrErrors);

  final List<Object> _openResponsesOrErrors;
  int _openCalls = 0;

  @override
  Future<List<BookingHistoryItem>> fetchDriverOpenBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    final idx = _openCalls < _openResponsesOrErrors.length
        ? _openCalls
        : _openResponsesOrErrors.length - 1;
    _openCalls += 1;
    final item = _openResponsesOrErrors[idx];
    if (item is AuthApiException) {
      throw item;
    }
    return item as List<BookingHistoryItem>;
  }

  @override
  Future<List<BookingHistoryItem>> fetchDriverBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return const <BookingHistoryItem>[];
  }
}

void main() {
  testWidgets('starts driver location loop when active trip is present', (
    tester,
  ) async {
    final api = _FakeDriverBookingApi();
    var providerCalls = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<DriverTabRefreshNotifier>(
            create: (_) => DriverTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: DriverNewRequestsScreen(
              bookingApi: api,
              locationTickerInterval: const Duration(milliseconds: 200),
              driverPositionProvider: () async {
                providerCalls += 1;
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(providerCalls, greaterThanOrEqualTo(1));
    expect(api.updateLocationCalls, 0);
  });

  testWidgets('continues polling and recovers request feed after a transient failure', (
    tester,
  ) async {
    final api = _FlakyDriverRequestFeedApi([
      const <BookingHistoryItem>[
        BookingHistoryItem(
          id: 'booking-open-1',
          status: 'requested',
          pickupAddress: 'Old pickup address',
          dropoffAddress: 'Airport',
          carTitle: 'City Sedan',
          paymentMaskedNumber: '**** 1111',
        ),
      ],
      AuthApiException('temporary outage'),
      const <BookingHistoryItem>[
        BookingHistoryItem(
          id: 'booking-open-1',
          status: 'requested',
          pickupAddress: 'Recovered pickup address',
          dropoffAddress: 'Airport',
          carTitle: 'City Sedan',
          paymentMaskedNumber: '**** 1111',
        ),
      ],
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthSession>.value(value: _FakeAuthSession()),
          ChangeNotifierProvider<DriverTabRefreshNotifier>(
            create: (_) => DriverTabRefreshNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: buildDrivepalTheme(),
          home: Scaffold(
            body: DriverNewRequestsScreen(
              bookingApi: api,
              requestFeedRefreshInterval: const Duration(milliseconds: 400),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old pickup address'), findsOneWidget);

    var recovered = false;
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 150));
      if (find.text('Recovered pickup address').evaluate().isNotEmpty) {
        recovered = true;
        break;
      }
    }
    expect(recovered, isTrue);
  });
}
