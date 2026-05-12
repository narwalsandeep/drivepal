import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/customer_tab_refresh_notifier.dart';
import '../../services/payment_methods_api.dart';
import '../../services/payment_methods_store.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  CustomerTabRefreshNotifier? _tabRefreshNotifier;
  int _walletTabRefreshVersion = 0;

  Future<bool> _confirmRemoveCard(PaymentMethodCard card) async {
    final didConfirm =
        await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: DrivepalTokens.bgCard,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                side: BorderSide(
                  color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
                ),
              ),
              title: Row(
                children: [
                  const Expanded(child: Text('Remove card?')),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: Text(
                'Remove ${card.brand.toUpperCase()} ${card.maskedNumber} from your wallet?',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: DrivepalTokens.textDanger,
                    foregroundColor: DrivepalTokens.textOnPrimary,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;
    return didConfirm;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadInitialState();
    });
  }

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(CustomerTabIndex.payment);
    if (nextVersion == _walletTabRefreshVersion) {
      return;
    }
    _walletTabRefreshVersion = nextVersion;
    final store = context.read<PaymentMethodsStore>();
    if (store.isAddingCard || store.busyCardId != null) {
      return;
    }
    unawaited(store.loadCards(context.read<AuthSession>()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<CustomerTabRefreshNotifier>();
    if (identical(notifier, _tabRefreshNotifier)) {
      return;
    }
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _tabRefreshNotifier = notifier;
    _walletTabRefreshVersion = notifier.versionFor(CustomerTabIndex.payment);
    notifier.addListener(_onTabRefreshTick);
  }

  @override
  void dispose() {
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final auth = context.read<AuthSession>();
    final store = context.read<PaymentMethodsStore>();
    final setupStatus = Uri.base.queryParameters['stripeSetup'];
    if (setupStatus == 'success') {
      await store.syncCards(auth);
      return;
    }
    if (setupStatus == 'cancelled') {
      await store.ensureLoaded(auth);
      return;
    }
    await store.ensureLoaded(auth);
  }

  Future<void> _addCard() async {
    final store = context.read<PaymentMethodsStore>();
    try {
      await store.addCard(context.read<AuthSession>());
      if (!mounted) {
        return;
      }
      if (!mounted || Uri.base.queryParameters['stripeSetup'] == 'success') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Redirecting to Stripe secure card setup...'
                : 'Card added successfully.',
          ),
        ),
      );
    } on StripeException {
      // Ignore cancel flow (already handled by Stripe sheet).
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeCard(PaymentMethodCard card) async {
    final shouldRemove = await _confirmRemoveCard(card);
    if (!mounted || !shouldRemove) {
      return;
    }
    final store = context.read<PaymentMethodsStore>();
    try {
      await store.removeCard(context.read<AuthSession>(), card);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Card removed.')));
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentMethodsStore>(
      builder: (context, store, _) {
        return RefreshIndicator(
          onRefresh: () => store.loadCards(context.read<AuthSession>()),
          child: ListView(
            padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
            children: [
              const DrivepalFeatureIntroCard(
                icon: Icons.account_balance_wallet_rounded,
                title: DrivepalAppShellCopy.riderWalletIntroTitle,
                subtitle: DrivepalAppShellCopy.riderWalletIntroSubtitle,
                badgeLabel: DrivepalAppShellCopy.riderWalletBadgeReady,
              ),
              const SizedBox(height: 6),
              const DrivepalProfileSectionLabel(
                DrivepalAppShellCopy.riderWalletSectionAddMethod,
              ),
              DrivepalElevatedPanel(
                padding: const EdgeInsets.all(14),
                child: FilledButton.tonalIcon(
                  onPressed: store.isAddingCard ? null : _addCard,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DrivepalTokens.radiusInput,
                      ),
                    ),
                  ),
                  icon:
                      store.isAddingCard
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.add_card_rounded),
                  label: Text(
                    store.isAddingCard
                        ? 'Opening secure card form...'
                        : DrivepalAppShellCopy.riderWalletAddCardCta,
                  ),
                ),
              ),
              const DrivepalProfileSectionLabel(
                DrivepalAppShellCopy.riderWalletSectionSavedCards,
              ),
              if (store.isLoading)
                const DrivepalElevatedPanel(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (store.cards.isEmpty)
                const DrivepalElevatedPanel(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: DrivepalPanelIconSummary(
                    iconData: Icons.credit_card_rounded,
                    title: DrivepalAppShellCopy.riderWalletNoCardsTitle,
                    body: DrivepalAppShellCopy.riderWalletNoCardsBody,
                  ),
                )
              else
                ...store.cards.map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DrivepalElevatedPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${card.brand.toUpperCase()} ${card.maskedNumber}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Exp ${card.expMonth.toString().padLeft(2, '0')}/${card.expYear}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (card.isDefault)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.black,
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed:
                                store.busyCardId == card.id
                                    ? null
                                    : () => _removeCard(card),
                            icon:
                                store.busyCardId == card.id
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.delete_outline_rounded,
                                      color: DrivepalTokens.textDanger,
                                    ),
                            tooltip: 'Remove card',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (store.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  store.error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black87),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
