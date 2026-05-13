import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import 'auth_api.dart';

class BookingApi {
  BookingApi({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? defaultApiBase();

  final http.Client _client;
  final String _apiBase;

  Uri _u(String path) => Uri.parse('$_apiBase/api/bookings$path');

  Future<BookingCarOptionsResponse> fetchCarOptions({
    String? bearerToken,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (bearerToken != null && bearerToken.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${bearerToken.trim()}';
      }
      final res = await _client.get(_u('/car-options'), headers: headers);
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) {
        return const BookingCarOptionsResponse(
          currencyCode: 'GBP',
          carOptions: <BookingCarOption>[],
        );
      }
      return BookingCarOptionsResponse.fromJson(decoded);
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> createRideBooking(
    Map<String, dynamic> body, {
    required String bearerToken,
  }) async {
    try {
      final res = await _client.post(
        _u(''),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<List<BookingHistoryItem>> fetchMyBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    try {
      final res = await _client.get(
        _u('/me?limit=$safeLimit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) return const <BookingHistoryItem>[];
      final raw = decoded['bookings'];
      if (raw is! List) return const <BookingHistoryItem>[];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                BookingHistoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> cancelBooking({
    required String bookingId,
    required String reasonCode,
    String? note,
    required String bearerToken,
  }) async {
    try {
      final res = await _client.patch(
        _u('/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode({
          'reasonCode': reasonCode,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<BookingTrackingSnapshot> fetchTrackingForBooking({
    required String bookingId,
    required String bearerToken,
  }) async {
    try {
      final res = await _client.get(
        _u('/$bookingId/tracking'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) {
        throw AuthApiException('Tracking data is unavailable right now.');
      }
      return BookingTrackingSnapshot.fromJson(decoded);
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<void> updateDriverLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required String bearerToken,
  }) async {
    try {
      final res = await _client.patch(
        _u('/$bookingId/driver-location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        }),
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<List<BookingHistoryItem>> fetchDriverOpenBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return _fetchBookingsList(
      path: '/driver/new',
      bearerToken: bearerToken,
      limit: limit,
    );
  }

  Future<List<BookingHistoryItem>> fetchDriverBookings({
    required String bearerToken,
    int limit = 100,
  }) async {
    return _fetchBookingsList(
      path: '/driver/me',
      bearerToken: bearerToken,
      limit: limit,
    );
  }

  Future<List<DriverEarningItem>> fetchDriverEarnings({
    required String bearerToken,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    try {
      final res = await _client.get(
        _u('/driver/earnings?limit=$safeLimit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) return const <DriverEarningItem>[];
      final raw = decoded['earnings'];
      if (raw is! List) return const <DriverEarningItem>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => DriverEarningItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<Map<String, dynamic>> acceptBookingAsDriver({
    required String bearerToken,
    required String bookingId,
  }) async {
    return _patchDriverBookingAction(
      path: '/$bookingId/accept',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> pickupBookingAsDriver({
    required String bearerToken,
    required String bookingId,
  }) async {
    return _patchDriverBookingAction(
      path: '/$bookingId/pickup',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> arriveBookingAsDriver({
    required String bearerToken,
    required String bookingId,
  }) async {
    return _patchDriverBookingAction(
      path: '/$bookingId/arrive',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> finishBookingAsDriver({
    required String bearerToken,
    required String bookingId,
  }) async {
    return _patchDriverBookingAction(
      path: '/$bookingId/finish',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> cancelBookingAsDriver({
    required String bearerToken,
    required String bookingId,
  }) async {
    return _patchDriverBookingAction(
      path: '/$bookingId/driver-cancel',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>> _patchDriverBookingAction({
    required String path,
    required String bearerToken,
  }) async {
    try {
      final res = await _client.patch(
        _u(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }

  Future<List<BookingHistoryItem>> _fetchBookingsList({
    required String path,
    required String bearerToken,
    required int limit,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    try {
      final res = await _client.get(
        _u('$path?limit=$safeLimit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
        },
      );
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      if (decoded is! Map<String, dynamic>) return const <BookingHistoryItem>[];
      final raw = decoded['bookings'];
      if (raw is! List) return const <BookingHistoryItem>[];
      return raw
          .whereType<Map>()
          .map(
            (item) =>
                BookingHistoryItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
  }
}

class BookingCarOption {
  const BookingCarOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.seats,
    required this.pricePerKmGbp,
  });

  final String id;
  final String title;
  final String subtitle;
  final int seats;
  final double pricePerKmGbp;

  factory BookingCarOption.fromJson(Map<String, dynamic> json) {
    return BookingCarOption(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      seats: (json['seats'] as num?)?.toInt() ?? 4,
      pricePerKmGbp: (json['pricePerKmGbp'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BookingCarOptionsResponse {
  const BookingCarOptionsResponse({
    required this.currencyCode,
    required this.carOptions,
  });

  final String currencyCode;
  final List<BookingCarOption> carOptions;

  factory BookingCarOptionsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['carOptions'];
    final options =
        raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (item) => BookingCarOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where(
                  (option) =>
                      option.id.trim().isNotEmpty &&
                      option.title.trim().isNotEmpty &&
                      option.seats > 0 &&
                      option.pricePerKmGbp > 0,
                )
                .toList()
            : const <BookingCarOption>[];
    return BookingCarOptionsResponse(
      currencyCode: (json['currencyCode'] ?? 'GBP').toString().toUpperCase(),
      carOptions: options,
    );
  }
}

class BookingHistoryItem {
  const BookingHistoryItem({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.carTitle,
    required this.paymentMaskedNumber,
    this.distanceMeters,
    this.durationSeconds,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.requestedAt,
    this.scheduledFor,
    this.acceptedAt,
    this.driverId,
    this.canCancel = false,
    this.cancellationReasonCode,
    this.cancellationNote,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final String carTitle;
  final String paymentMaskedNumber;
  final int? distanceMeters;
  final int? durationSeconds;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final DateTime? requestedAt;
  final DateTime? scheduledFor;
  final DateTime? acceptedAt;
  final String? driverId;
  final bool canCancel;
  final String? cancellationReasonCode;
  final String? cancellationNote;

  factory BookingHistoryItem.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'];
    final dropoff = json['dropoff'];
    final car = json['car'];
    final payment = json['payment'];
    final route = json['route'];
    final requestedAtRaw = json['requestedAt'];
    final scheduledForRaw = json['scheduledFor'];
    final acceptedAtRaw = json['acceptedAt'];
    final driver = json['driver'];
    final cancellation = json['cancellation'];
    return BookingHistoryItem(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'requested').toString(),
      pickupAddress: pickup is Map ? (pickup['address'] ?? '').toString() : '',
      dropoffAddress:
          dropoff is Map ? (dropoff['address'] ?? '').toString() : '',
      pickupLatitude:
          pickup is Map ? (pickup['latitude'] as num?)?.toDouble() : null,
      pickupLongitude:
          pickup is Map ? (pickup['longitude'] as num?)?.toDouble() : null,
      dropoffLatitude:
          dropoff is Map ? (dropoff['latitude'] as num?)?.toDouble() : null,
      dropoffLongitude:
          dropoff is Map ? (dropoff['longitude'] as num?)?.toDouble() : null,
      carTitle: car is Map ? (car['title'] ?? '').toString() : '',
      paymentMaskedNumber:
          payment is Map ? (payment['maskedNumber'] ?? '').toString() : '',
      distanceMeters:
          route is Map ? (route['distanceMeters'] as num?)?.toInt() : null,
      durationSeconds:
          route is Map ? (route['durationSeconds'] as num?)?.toInt() : null,
      requestedAt:
          requestedAtRaw is String ? DateTime.tryParse(requestedAtRaw) : null,
      scheduledFor:
          scheduledForRaw is String ? DateTime.tryParse(scheduledForRaw) : null,
      acceptedAt:
          acceptedAtRaw is String ? DateTime.tryParse(acceptedAtRaw) : null,
      driverId: driver is Map ? (driver['id'] as String?) : null,
      canCancel: json['canCancel'] == true,
      cancellationReasonCode:
          cancellation is Map ? (cancellation['reasonCode'] as String?) : null,
      cancellationNote:
          cancellation is Map ? (cancellation['note'] as String?) : null,
    );
  }
}

class BookingDriverLocation {
  const BookingDriverLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? recordedAt;

  factory BookingDriverLocation.fromJson(Map<String, dynamic> json) {
    final recordedAtRaw = json['recordedAt'];
    return BookingDriverLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      recordedAt:
          recordedAtRaw is String ? DateTime.tryParse(recordedAtRaw) : null,
    );
  }
}

class BookingTrackingSnapshot {
  const BookingTrackingSnapshot({required this.booking, this.driverLocation});

  final BookingHistoryItem booking;
  final BookingDriverLocation? driverLocation;

  factory BookingTrackingSnapshot.fromJson(Map<String, dynamic> json) {
    final tracking = json['tracking'];
    if (tracking is! Map<String, dynamic>) {
      throw AuthApiException('Tracking response format is invalid.');
    }
    final bookingRaw = tracking['booking'];
    if (bookingRaw is! Map<String, dynamic>) {
      throw AuthApiException('Booking payload is missing in tracking response.');
    }
    final locationRaw = tracking['driverLocation'];
    return BookingTrackingSnapshot(
      booking: BookingHistoryItem.fromJson(bookingRaw),
      driverLocation:
          locationRaw is Map<String, dynamic>
              ? BookingDriverLocation.fromJson(locationRaw)
              : null,
    );
  }
}

class DriverEarningItem {
  const DriverEarningItem({
    required this.id,
    required this.bookingId,
    required this.grossAmountMinor,
    required this.platformFeeMinor,
    required this.driverAmountMinor,
    required this.driverShareBps,
    required this.currencyCode,
    required this.calculatedAt,
    this.pickupAddress,
    this.dropoffAddress,
    this.carTitle,
    this.requestedAt,
    this.completedAt,
  });

  final String id;
  final String bookingId;
  final int grossAmountMinor;
  final int platformFeeMinor;
  final int driverAmountMinor;
  final int driverShareBps;
  final String currencyCode;
  final DateTime calculatedAt;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? carTitle;
  final DateTime? requestedAt;
  final DateTime? completedAt;

  factory DriverEarningItem.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'];
    final calculatedAtRaw = json['calculatedAt'];
    return DriverEarningItem(
      id: (json['id'] ?? '').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      grossAmountMinor: (json['grossAmountMinor'] as num?)?.toInt() ?? 0,
      platformFeeMinor: (json['platformFeeMinor'] as num?)?.toInt() ?? 0,
      driverAmountMinor: (json['driverAmountMinor'] as num?)?.toInt() ?? 0,
      driverShareBps: (json['driverShareBps'] as num?)?.toInt() ?? 0,
      currencyCode: (json['currencyCode'] ?? 'GBP').toString().toUpperCase(),
      calculatedAt:
          calculatedAtRaw is String
              ? DateTime.tryParse(calculatedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.fromMillisecondsSinceEpoch(0),
      pickupAddress: trip is Map ? (trip['pickupAddress'] as String?) : null,
      dropoffAddress: trip is Map ? (trip['dropoffAddress'] as String?) : null,
      carTitle: trip is Map ? (trip['carTitle'] as String?) : null,
      requestedAt:
          trip is Map && trip['requestedAt'] is String
              ? DateTime.tryParse(trip['requestedAt'] as String)
              : null,
      completedAt:
          trip is Map && trip['completedAt'] is String
              ? DateTime.tryParse(trip['completedAt'] as String)
              : null,
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
