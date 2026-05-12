import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final BookingApi _bookingApi = BookingApi();
  bool _loading = true;
  String? _error;
  List<DriverEarningItem> _items = const <DriverEarningItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Sign in again to view earnings.';
        });
        return;
      }
      final rows = await _bookingApi.fetchDriverEarnings(bearerToken: token);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  String _formatMoney(int minor, String currencyCode) {
    final major = minor / 100;
    if (currencyCode == 'GBP') {
      return '£${major.toStringAsFixed(2)}';
    }
    return '${major.toStringAsFixed(2)} $currencyCode';
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '—';
    }
    final local = dateTime.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  int get _totalDriverAmountMinor =>
      _items.fold<int>(0, (sum, item) => sum + item.driverAmountMinor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Earning')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            DrivepalFeatureIntroCard(
              icon: Icons.payments_rounded,
              title: 'Driver earnings',
              subtitle:
                  'Earnings are calculated after ride completion. Driver share is 10% per trip.',
            ),
            const SizedBox(height: 10),
            DrivepalElevatedPanel(
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Total earnings',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatMoney(_totalDriverAmountMinor, 'GBP'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DrivepalTokens.textHeading,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const DrivepalElevatedPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              DrivepalElevatedPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DrivepalTokens.textBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              const DrivepalElevatedPanel(
                padding: EdgeInsets.symmetric(vertical: 26, horizontal: 18),
                child: DrivepalEmptyStateBlock(
                  icon: Icons.receipt_long_rounded,
                  title: 'No earnings yet',
                  body:
                      'Complete rides to generate driver earnings. Earnings are posted after trip completion.',
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DrivepalElevatedPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatMoney(
                                  item.driverAmountMinor,
                                  item.currencyCode,
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: DrivepalTokens.locationDropoff,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Text(
                              '10%',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: DrivepalTokens.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.pickupAddress ?? 'Pickup'} -> ${item.dropoffAddress ?? 'Drop-off'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DrivepalTokens.textHeading,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trip total: ${_formatMoney(item.grossAmountMinor, item.currencyCode)}'
                          '  |  Platform fee: ${_formatMoney(item.platformFeeMinor, item.currencyCode)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DrivepalTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completed: ${_formatDateTime(item.completedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DrivepalTokens.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      backgroundColor: DrivepalTokens.bgScaffold,
    );
  }
}
