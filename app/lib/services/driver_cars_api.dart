import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import 'auth_api.dart';

class DriverCarsApi {
  DriverCarsApi({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? defaultApiBase();

  final http.Client _client;
  final String _apiBase;

  Uri _u(String path) => Uri.parse('$_apiBase/api/driver-cars$path');

  Future<List<DriverCarItem>> listMine({required String bearerToken}) async {
    try {
      final res = await _client.get(
        _u('/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) return const <DriverCarItem>[];
      final raw = decoded['cars'];
      if (raw is! List) return const <DriverCarItem>[];
      return raw
          .whereType<Map>()
          .map((item) => DriverCarItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<DriverCarItem> create({
    required String bearerToken,
    required DriverCarInput input,
  }) async {
    return _save(path: '', bearerToken: bearerToken, input: input);
  }

  Future<DriverCarItem> update({
    required String bearerToken,
    required String carId,
    required DriverCarInput input,
  }) async {
    return _save(path: '/$carId', bearerToken: bearerToken, input: input);
  }

  Future<DriverCarItem> _save({
    required String path,
    required String bearerToken,
    required DriverCarInput input,
  }) async {
    try {
      final res =
          path.isEmpty
              ? await _client.post(
                _u(path),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $bearerToken',
                },
                body: jsonEncode(input.toJson()),
              )
              : await _client.patch(
                _u(path),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $bearerToken',
                },
                body: jsonEncode(input.toJson()),
              );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) {
        throw AuthApiException('Invalid car response from server');
      }
      final rawCar = decoded['car'];
      if (rawCar is! Map) {
        throw AuthApiException('Invalid car payload from server');
      }
      return DriverCarItem.fromJson(Map<String, dynamic>.from(rawCar));
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }
}

class DriverCarInput {
  const DriverCarInput({
    required this.displayName,
    required this.manufacturer,
    required this.model,
    required this.color,
    required this.plateNumber,
    required this.seatCapacity,
    required this.carTypeId,
    required this.transmission,
    required this.isActive,
    required this.acceptsPets,
    required this.hasAirConditioning,
    required this.hasChildSeat,
    required this.wheelchairAccessible,
  });

  final String displayName;
  final String manufacturer;
  final String model;
  final String color;
  final String plateNumber;
  final int seatCapacity;
  final String carTypeId;
  final String transmission;
  final bool isActive;
  final bool acceptsPets;
  final bool hasAirConditioning;
  final bool hasChildSeat;
  final bool wheelchairAccessible;

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'manufacturer': manufacturer,
    'model': model,
    'color': color,
    'plateNumber': plateNumber,
    'seatCapacity': seatCapacity,
    'carTypeId': carTypeId,
    'transmission': transmission,
    'isActive': isActive,
    'acceptsPets': acceptsPets,
    'hasAirConditioning': hasAirConditioning,
    'hasChildSeat': hasChildSeat,
    'wheelchairAccessible': wheelchairAccessible,
  };

  DriverCarInput copyWith({
    String? displayName,
    String? manufacturer,
    String? model,
    String? color,
    String? plateNumber,
    int? seatCapacity,
    String? carTypeId,
    String? transmission,
    bool? isActive,
    bool? acceptsPets,
    bool? hasAirConditioning,
    bool? hasChildSeat,
    bool? wheelchairAccessible,
  }) {
    return DriverCarInput(
      displayName: displayName ?? this.displayName,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      color: color ?? this.color,
      plateNumber: plateNumber ?? this.plateNumber,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      carTypeId: carTypeId ?? this.carTypeId,
      transmission: transmission ?? this.transmission,
      isActive: isActive ?? this.isActive,
      acceptsPets: acceptsPets ?? this.acceptsPets,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      hasChildSeat: hasChildSeat ?? this.hasChildSeat,
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
    );
  }
}

class DriverCarItem {
  const DriverCarItem({
    required this.id,
    required this.displayName,
    required this.manufacturer,
    required this.model,
    required this.color,
    required this.plateNumber,
    required this.seatCapacity,
    required this.carTypeId,
    required this.carTypeTitle,
    required this.pricePerKmGbp,
    required this.transmission,
    required this.isActive,
    required this.acceptsPets,
    required this.hasAirConditioning,
    required this.hasChildSeat,
    required this.wheelchairAccessible,
  });

  final String id;
  final String displayName;
  final String manufacturer;
  final String model;
  final String color;
  final String plateNumber;
  final int seatCapacity;
  final String carTypeId;
  final String carTypeTitle;
  final double pricePerKmGbp;
  final String transmission;
  final bool isActive;
  final bool acceptsPets;
  final bool hasAirConditioning;
  final bool hasChildSeat;
  final bool wheelchairAccessible;

  DriverCarInput toInput() => DriverCarInput(
    displayName: displayName,
    manufacturer: manufacturer,
    model: model,
    color: color,
    plateNumber: plateNumber,
    seatCapacity: seatCapacity,
    carTypeId: carTypeId,
    transmission: transmission,
    isActive: isActive,
    acceptsPets: acceptsPets,
    hasAirConditioning: hasAirConditioning,
    hasChildSeat: hasChildSeat,
    wheelchairAccessible: wheelchairAccessible,
  );

  factory DriverCarItem.fromJson(Map<String, dynamic> json) {
    final features = json['features'];
    final carType = json['carType'];
    return DriverCarItem(
      id: (json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      manufacturer: (json['manufacturer'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      plateNumber: (json['plateNumber'] ?? '').toString(),
      seatCapacity: (json['seatCapacity'] as num?)?.toInt() ?? 4,
      carTypeId:
          carType is Map
              ? (carType['id'] ?? 'sedan4').toString()
              : (json['carTypeId'] ?? 'sedan4').toString(),
      carTypeTitle:
          carType is Map
              ? (carType['title'] ?? 'City Sedan').toString()
              : 'City Sedan',
      pricePerKmGbp:
          carType is Map
              ? (carType['pricePerKmGbp'] as num?)?.toDouble() ?? 1.45
              : 1.45,
      transmission: (json['transmission'] ?? 'automatic').toString(),
      isActive: json['isActive'] != false,
      acceptsPets: features is Map ? features['acceptsPets'] == true : false,
      hasAirConditioning:
          features is Map ? features['hasAirConditioning'] != false : true,
      hasChildSeat: features is Map ? features['hasChildSeat'] == true : false,
      wheelchairAccessible:
          features is Map ? features['wheelchairAccessible'] == true : false,
    );
  }
}

String _formatError(Object? decoded, int code) {
  if (decoded is Map<String, dynamic>) {
    final m = decoded['message'];
    if (m is List) return m.map((e) => e.toString()).join(', ');
    if (m is String) return m;
  }
  return 'Request failed ($code)';
}
