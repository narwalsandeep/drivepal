import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import 'auth_api.dart';

class PaymentMethodCard {
  const PaymentMethodCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.maskedNumber,
    required this.isDefault,
    this.funding,
    this.country,
  });

  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String maskedNumber;
  final bool isDefault;
  final String? funding;
  final String? country;

  factory PaymentMethodCard.fromJson(Map<String, dynamic> json) {
    return PaymentMethodCard(
      id: (json['id'] ?? '').toString(),
      brand: (json['brand'] ?? 'card').toString(),
      last4: (json['last4'] ?? '').toString(),
      expMonth: (json['expMonth'] as num?)?.toInt() ?? 0,
      expYear: (json['expYear'] as num?)?.toInt() ?? 0,
      maskedNumber: (json['maskedNumber'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
      funding: json['funding'] as String?,
      country: json['country'] as String?,
    );
  }

  String get label => '$brand $maskedNumber';
}

class PaymentSheetSetupIntentResponse {
  const PaymentSheetSetupIntentResponse({
    required this.setupIntentClientSecret,
    required this.customerId,
    required this.customerEphemeralKeySecret,
    required this.publishableKey,
  });

  final String setupIntentClientSecret;
  final String customerId;
  final String customerEphemeralKeySecret;
  final String publishableKey;

  factory PaymentSheetSetupIntentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentSheetSetupIntentResponse(
      setupIntentClientSecret:
          (json['setupIntentClientSecret'] ?? '').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      customerEphemeralKeySecret:
          (json['customerEphemeralKeySecret'] ?? '').toString(),
      publishableKey: (json['publishableKey'] ?? '').toString(),
    );
  }
}

class WebSetupSessionResponse {
  const WebSetupSessionResponse({required this.url});

  final String url;

  factory WebSetupSessionResponse.fromJson(Map<String, dynamic> json) {
    return WebSetupSessionResponse(url: (json['url'] ?? '').toString());
  }
}

class PaymentMethodsApi {
  PaymentMethodsApi({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? defaultApiBase();

  final http.Client _client;
  final String _apiBase;

  Uri _u(String path) => Uri.parse('$_apiBase/api/payments$path');

  Map<String, String> _authHeaders(String bearerToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $bearerToken',
  };

  Future<List<PaymentMethodCard>> listCards({
    required String bearerToken,
  }) async {
    final decoded = await _requestJson(
      () => _client.get(_u('/cards'), headers: _authHeaders(bearerToken)),
    );
    if (decoded is! Map<String, dynamic>) return const <PaymentMethodCard>[];
    final cards = decoded['cards'];
    if (cards is! List) return const <PaymentMethodCard>[];
    return cards
        .whereType<Map>()
        .map(
          (item) => PaymentMethodCard.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<PaymentSheetSetupIntentResponse> createSetupIntent({
    required String bearerToken,
  }) async {
    final decoded = await _requestJson(
      () =>
          _client.post(_u('/setup-intent'), headers: _authHeaders(bearerToken)),
    );
    if (decoded is! Map<String, dynamic>) {
      throw AuthApiException('Invalid setup intent response');
    }
    return PaymentSheetSetupIntentResponse.fromJson(decoded);
  }

  Future<List<PaymentMethodCard>> syncCards({
    required String bearerToken,
  }) async {
    final decoded = await _requestJson(
      () => _client.post(_u('/cards/sync'), headers: _authHeaders(bearerToken)),
    );
    if (decoded is! Map<String, dynamic>) return const <PaymentMethodCard>[];
    final cards = decoded['cards'];
    if (cards is! List) return const <PaymentMethodCard>[];
    return cards
        .whereType<Map>()
        .map(
          (item) => PaymentMethodCard.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<WebSetupSessionResponse> createWebSetupSession({
    required String bearerToken,
    required String returnUrl,
  }) async {
    final decoded = await _requestJson(
      () => _client.post(
        _u('/web/setup-session'),
        headers: _authHeaders(bearerToken),
        body: jsonEncode({'returnUrl': returnUrl}),
      ),
    );
    if (decoded is! Map<String, dynamic>) {
      throw AuthApiException('Invalid web setup session response');
    }
    return WebSetupSessionResponse.fromJson(decoded);
  }

  Future<List<PaymentMethodCard>> removeCard({
    required String bearerToken,
    required String cardId,
  }) async {
    final decoded = await _requestJson(
      () => _client.delete(
        _u('/cards/$cardId'),
        headers: _authHeaders(bearerToken),
      ),
    );
    if (decoded is! Map<String, dynamic>) return const <PaymentMethodCard>[];
    final cards = decoded['cards'];
    if (cards is! List) return const <PaymentMethodCard>[];
    return cards
        .whereType<Map>()
        .map(
          (item) => PaymentMethodCard.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Object?> _requestJson(Future<http.Response> Function() request) async {
    try {
      final res = await request();
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Object?;
      if (res.statusCode >= 400) {
        throw AuthApiException(_formatError(decoded, res.statusCode));
      }
      return decoded;
    } on http.ClientException catch (e) {
      throw AuthApiException(
        'Could not reach API at $_apiBase (network/CORS). '
        'Is Nest running on port 3000? ${e.message}',
      );
    }
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
