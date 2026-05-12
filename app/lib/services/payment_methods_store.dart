import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../platform/open_url.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'payment_methods_api.dart';

class PaymentMethodsStore extends ChangeNotifier {
  PaymentMethodsStore({PaymentMethodsApi? api})
    : _api = api ?? PaymentMethodsApi();

  final PaymentMethodsApi _api;

  List<PaymentMethodCard> _cards = const <PaymentMethodCard>[];
  bool _loading = false;
  bool _addingCard = false;
  String? _busyCardId;
  String? _error;
  bool _loadedOnce = false;

  List<PaymentMethodCard> get cards => _cards;
  bool get isLoading => _loading;
  bool get isAddingCard => _addingCard;
  String? get busyCardId => _busyCardId;
  String? get error => _error;
  bool get hasCards => _cards.isNotEmpty;

  Future<void> ensureLoaded(AuthSession authSession) async {
    if (_loadedOnce) return;
    await loadCards(authSession);
  }

  Future<void> syncCards(AuthSession authSession) async {
    final token = await authSession.getValidAccessToken();
    if (token == null) {
      _cards = const <PaymentMethodCard>[];
      _error = 'Please sign in again to manage payment cards.';
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _cards = await _api.syncCards(bearerToken: token);
      _loadedOnce = true;
    } on AuthApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCards(AuthSession authSession) async {
    final token = await authSession.getValidAccessToken();
    if (token == null) {
      _cards = const <PaymentMethodCard>[];
      _error = 'Please sign in again to manage payment cards.';
      _loadedOnce = true;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _cards = await _api.listCards(bearerToken: token);
      _loadedOnce = true;
    } on AuthApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addCard(AuthSession authSession) async {
    final token = await authSession.getValidAccessToken();
    if (token == null) {
      _error = 'Please sign in again to add a card.';
      notifyListeners();
      throw AuthApiException(_error!);
    }

    _addingCard = true;
    _error = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        final session = await _api.createWebSetupSession(
          bearerToken: token,
          returnUrl: Uri.base.removeFragment().toString(),
        );
        if (session.url.trim().isEmpty) {
          throw AuthApiException('Unable to open Stripe setup page.');
        }
        await openCurrentTabUrl(session.url.trim());
        return;
      }
      final setup = await _api.createSetupIntent(bearerToken: token);
      if (setup.publishableKey.trim().isNotEmpty &&
          Stripe.publishableKey != setup.publishableKey.trim()) {
        Stripe.publishableKey = setup.publishableKey.trim();
        await Stripe.instance.applySettings();
      }
      if (Stripe.publishableKey.trim().isEmpty) {
        throw AuthApiException('Stripe publishable key is not configured.');
      }
      if (setup.setupIntentClientSecret.trim().isEmpty ||
          setup.customerId.trim().isEmpty ||
          setup.customerEphemeralKeySecret.trim().isEmpty) {
        throw AuthApiException('Invalid payment setup from server.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setup.setupIntentClientSecret,
          customerId: setup.customerId,
          customerEphemeralKeySecret: setup.customerEphemeralKeySecret,
          merchantDisplayName: 'DRIVEPAL',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      _cards = await _api.syncCards(bearerToken: token);
      _loadedOnce = true;
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        _error = e.error.localizedMessage ?? 'Unable to add card right now.';
        notifyListeners();
      }
      rethrow;
    } on AuthApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Unable to add card right now. Please try again.';
      notifyListeners();
      throw AuthApiException(e.toString());
    } finally {
      _addingCard = false;
      notifyListeners();
    }
  }

  Future<void> removeCard(
    AuthSession authSession,
    PaymentMethodCard card,
  ) async {
    final token = await authSession.getValidAccessToken();
    if (token == null) {
      _error = 'Please sign in again to manage payment cards.';
      notifyListeners();
      throw AuthApiException(_error!);
    }
    _busyCardId = card.id;
    _error = null;
    notifyListeners();
    try {
      _cards = await _api.removeCard(bearerToken: token, cardId: card.id);
      _loadedOnce = true;
    } on AuthApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _busyCardId = null;
      notifyListeners();
    }
  }
}
