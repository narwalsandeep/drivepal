import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/driver_tab_refresh_notifier.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_booking_status_theme.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/common/drivepal_location_icon.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  final BookingApi _bookingApi = BookingApi();
  bool _loading = true;
  String? _error;
  List<BookingHistoryItem> _items = const <BookingHistoryItem>[];
  DriverTabRefreshNotifier? _tabRefreshNotifier;
  int _tripsTabRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(DriverTabIndex.trips);
    if (nextVersion == _tripsTabRefreshVersion) {
      return;
    }
    _tripsTabRefreshVersion = nextVersion;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<DriverTabRefreshNotifier>();
    if (identical(notifier, _tabRefreshNotifier)) {
      return;
    }
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _tabRefreshNotifier = notifier;
    _tripsTabRefreshVersion = notifier.versionFor(DriverTabIndex.trips);
    notifier.addListener(_onTabRefreshTick);
  }

  @override
  void dispose() {
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    super.dispose();
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
          _error = 'Sign in again to view trips.';
        });
        return;
      }
      final rows = await _bookingApi.fetchDriverBookings(bearerToken: token);
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

  String _statusLabel(String status) {
    return DrivepalBookingStatusTheme.fromStatus(status).driverLabel;
  }

  String _routeFacts(BookingHistoryItem item) {
    final bits = <String>[];
    if (item.durationSeconds != null) {
      final mins = (item.durationSeconds! / 60).round();
      bits.add(mins < 60 ? '$mins min' : '${mins ~/ 60}h ${mins % 60}m');
    }
    if (item.distanceMeters != null) {
      final km = item.distanceMeters! / 1000;
      bits.add(
        km >= 10 ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km',
      );
    }
    return bits.isEmpty ? 'Route details pending' : bits.join('  •  ');
  }

  Widget _tripCard(BuildContext context, BookingHistoryItem item) {
    final statusVisual = DrivepalBookingStatusTheme.fromStatus(item.status);
    final tt = Theme.of(context).textTheme;
    final requestedAt = item.requestedAt;
    final requestedAtText =
        requestedAt == null
            ? null
            : '${requestedAt.day.toString().padLeft(2, '0')}/'
                '${requestedAt.month.toString().padLeft(2, '0')} '
                '${requestedAt.hour.toString().padLeft(2, '0')}:'
                '${requestedAt.minute.toString().padLeft(2, '0')}';

    return DrivepalElevatedPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusVisual.surfaceColor,
                  ),
                  child: Icon(
                    statusVisual.icon,
                    size: 16,
                    color: statusVisual.accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusLabel(item.status),
                    style: tt.titleSmall?.copyWith(
                      color: statusVisual.accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (requestedAtText != null)
                  Text(
                    requestedAtText,
                    style: tt.bodySmall?.copyWith(
                      color: DrivepalTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: DrivepalTokens.borderCard.withValues(alpha: 0.9),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const DrivepalLocationIcon(
                      icon: Icons.radio_button_checked_rounded,
                      role: DrivepalLocationRole.pickup,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.pickupAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: DrivepalTokens.textHeading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const DrivepalLocationIcon(
                      icon: Icons.location_on_rounded,
                      role: DrivepalLocationRole.dropoff,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.dropoffAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: DrivepalTokens.borderCard.withValues(alpha: 0.9),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _routeFacts(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: DrivepalTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.carTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: tt.bodySmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
        children: [
          const DrivepalFeatureIntroCard(
            icon: Icons.alt_route_rounded,
            title: DrivepalAppShellCopy.driverTripsIntroTitle,
            subtitle: DrivepalAppShellCopy.driverTripsIntroSubtitle,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DrivepalAppShellCopy.driverTripsSectionCompleted.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.25,
                      fontWeight: FontWeight.w700,
                      color: DrivepalTokens.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          if (_loading)
            const DrivepalElevatedPanel(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
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
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 18),
              child: DrivepalEmptyStateBlock(
                icon: Icons.route_rounded,
                title: DrivepalAppShellCopy.driverTripsEmptyTitle,
                body: DrivepalAppShellCopy.driverTripsEmptyBody,
              ),
            )
          else
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _tripCard(context, item),
              ),
            ),
        ],
      ),
    );
  }
}
