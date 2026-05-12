import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivepal_app/services/auth_api.dart';
import 'package:drivepal_app/services/booking_api.dart';

void main() {
  test('fetchCarOptions parses configured cars and currency code', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/bookings/car-options');
      return http.Response(
        jsonEncode({
          'currencyCode': 'GBP',
          'carOptions': [
            {
              'id': 'sedan4',
              'title': 'City Sedan',
              'subtitle': 'Comfort ride for everyday trips',
              'seats': 4,
              'pricePerKmGbp': 1.45,
            },
          ],
        }),
        200,
      );
    });
    final api = BookingApi(client: client, apiBase: 'http://localhost:3000');

    final response = await api.fetchCarOptions();

    expect(response.currencyCode, 'GBP');
    expect(response.carOptions, hasLength(1));
    expect(response.carOptions.first.id, 'sedan4');
    expect(response.carOptions.first.pricePerKmGbp, 1.45);
  });

  test('fetchCarOptions throws AuthApiException on API error', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'message': 'boom'}), 400),
    );
    final api = BookingApi(client: client, apiBase: 'http://localhost:3000');

    await expectLater(api.fetchCarOptions(), throwsA(isA<AuthApiException>()));
  });

  test('fetchDriverOpenBookings parses booking list', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/bookings/driver/new');
      return http.Response(
        jsonEncode({
          'bookings': [
            {
              'id': 'b1',
              'status': 'requested',
              'pickup': {'address': 'A'},
              'dropoff': {'address': 'B'},
              'car': {'title': 'City Sedan'},
              'payment': {'maskedNumber': '**** 1111'},
              'route': {'distanceMeters': 1000, 'durationSeconds': 300},
              'driver': {'id': null},
              'requestedAt': '2026-05-09T12:00:00.000Z',
              'scheduledFor': '2026-05-09T12:20:00.000Z',
            },
          ],
        }),
        200,
      );
    });
    final api = BookingApi(client: client, apiBase: 'http://localhost:3000');
    final rows = await api.fetchDriverOpenBookings(bearerToken: 'token');
    expect(rows, hasLength(1));
    expect(rows.first.id, 'b1');
    expect(rows.first.status, 'requested');
    expect(rows.first.scheduledFor, isNotNull);
  });

  test('acceptBookingAsDriver throws on API error', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'message': 'conflict'}), 409),
    );
    final api = BookingApi(client: client, apiBase: 'http://localhost:3000');
    await expectLater(
      api.acceptBookingAsDriver(bearerToken: 'token', bookingId: 'b1'),
      throwsA(isA<AuthApiException>()),
    );
  });

  test('fetchDriverEarnings parses earnings list', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/bookings/driver/earnings');
      return http.Response(
        jsonEncode({
          'earnings': [
            {
              'id': 'e1',
              'bookingId': 'b1',
              'grossAmountMinor': 2000,
              'platformFeeMinor': 1800,
              'driverAmountMinor': 200,
              'driverShareBps': 1000,
              'currencyCode': 'GBP',
              'calculatedAt': '2026-05-12T10:00:00.000Z',
              'trip': {
                'pickupAddress': 'A',
                'dropoffAddress': 'B',
                'completedAt': '2026-05-12T09:50:00.000Z',
              },
            },
          ],
        }),
        200,
      );
    });
    final api = BookingApi(client: client, apiBase: 'http://localhost:3000');
    final rows = await api.fetchDriverEarnings(bearerToken: 'token');
    expect(rows, hasLength(1));
    expect(rows.first.id, 'e1');
    expect(rows.first.driverAmountMinor, 200);
    expect(rows.first.completedAt, isNotNull);
  });
}
