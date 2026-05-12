import 'package:flutter_test/flutter_test.dart';
import 'package:drivepal_app/services/auth_api.dart';
import 'package:drivepal_app/services/auth_session.dart';
import 'package:drivepal_app/services/payment_methods_api.dart';
import 'package:drivepal_app/services/payment_methods_store.dart';

class _FakeAuthSession extends AuthSession {
  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _FakePaymentMethodsApi extends PaymentMethodsApi {
  _FakePaymentMethodsApi({
    required this.listResponse,
    required this.removeResponse,
  });

  final List<PaymentMethodCard> listResponse;
  final List<PaymentMethodCard> removeResponse;
  bool listCalled = false;
  bool removeCalled = false;

  @override
  Future<List<PaymentMethodCard>> listCards({
    required String bearerToken,
  }) async {
    listCalled = true;
    if (bearerToken.isEmpty) {
      throw AuthApiException('bad token');
    }
    return listResponse;
  }

  @override
  Future<List<PaymentMethodCard>> removeCard({
    required String bearerToken,
    required String cardId,
  }) async {
    removeCalled = true;
    if (cardId.isEmpty) {
      throw AuthApiException('bad card id');
    }
    return removeResponse;
  }
}

void main() {
  test('loadCards populates state with API response', () async {
    const firstCard = PaymentMethodCard(
      id: 'card_1',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
      maskedNumber: '**** **** **** 4242',
      isDefault: true,
    );
    final api = _FakePaymentMethodsApi(
      listResponse: const [firstCard],
      removeResponse: const [],
    );
    final store = PaymentMethodsStore(api: api);

    await store.loadCards(_FakeAuthSession());

    expect(api.listCalled, isTrue);
    expect(store.cards, hasLength(1));
    expect(store.cards.first.id, 'card_1');
    expect(store.error, isNull);
  });

  test('removeCard updates list returned by API', () async {
    const firstCard = PaymentMethodCard(
      id: 'card_1',
      brand: 'visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2030,
      maskedNumber: '**** **** **** 4242',
      isDefault: true,
    );
    const secondCard = PaymentMethodCard(
      id: 'card_2',
      brand: 'mastercard',
      last4: '5454',
      expMonth: 10,
      expYear: 2029,
      maskedNumber: '**** **** **** 5454',
      isDefault: false,
    );
    final api = _FakePaymentMethodsApi(
      listResponse: const [firstCard, secondCard],
      removeResponse: const [secondCard],
    );
    final store = PaymentMethodsStore(api: api);
    await store.loadCards(_FakeAuthSession());

    await store.removeCard(_FakeAuthSession(), firstCard);

    expect(api.removeCalled, isTrue);
    expect(store.cards, hasLength(1));
    expect(store.cards.first.id, 'card_2');
  });
}
