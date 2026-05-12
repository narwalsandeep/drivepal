import 'dart:convert';

import 'package:drivepal_app/services/auth_api.dart';
import 'package:drivepal_app/services/driver_cars_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('listMine parses cars list', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/driver-cars/me');
      return http.Response(
        jsonEncode({
          'cars': [
            {
              'id': 'car-1',
              'displayName': 'Daily Ride',
              'manufacturer': 'Toyota',
              'model': 'Corolla',
              'color': 'Black',
              'plateNumber': 'AB12 CDE',
              'seatCapacity': 4,
              'carType': {
                'id': 'mpv5',
                'title': 'Family Plus',
                'pricePerKmGbp': 1.7,
              },
              'transmission': 'automatic',
              'isActive': true,
              'features': {
                'acceptsPets': false,
                'hasAirConditioning': true,
                'hasChildSeat': false,
                'wheelchairAccessible': false,
              },
            },
          ],
        }),
        200,
      );
    });
    final api = DriverCarsApi(client: client, apiBase: 'http://localhost:3000');
    final rows = await api.listMine(bearerToken: 'token');
    expect(rows, hasLength(1));
    expect(rows.first.id, 'car-1');
    expect(rows.first.pricePerKmGbp, 1.7);
    expect(rows.first.carTypeId, 'mpv5');
  });

  test('create throws AuthApiException on API validation error', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'message': 'invalid'}), 400),
    );
    final api = DriverCarsApi(client: client, apiBase: 'http://localhost:3000');
    await expectLater(
      api.create(
        bearerToken: 'token',
        input: const DriverCarInput(
          displayName: 'Daily Ride',
          manufacturer: 'Toyota',
          model: 'Corolla',
          color: 'Black',
          plateNumber: 'AB12 CDE',
          seatCapacity: 4,
          carTypeId: 'mpv5',
          transmission: 'automatic',
          isActive: true,
          acceptsPets: false,
          hasAirConditioning: true,
          hasChildSeat: false,
          wheelchairAccessible: false,
        ),
      ),
      throwsA(isA<AuthApiException>()),
    );
  });
}
