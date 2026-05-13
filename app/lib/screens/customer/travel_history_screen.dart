import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/customer_tab_refresh_notifier.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_booking_status_theme.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/common/drivepal_location_icon.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';

/// Rider trip history from API bookings (latest on top).
class TravelHistoryScreen extends StatefulWidget {
  const TravelHistoryScreen({super.key, this.bookingApi});

  final BookingApi? bookingApi;

  @override
  State<TravelHistoryScreen> createState() => _TravelHistoryScreenState();
}

class _TravelHistoryScreenState extends State<TravelHistoryScreen> {
  late final BookingApi _bookingApi = widget.bookingApi ?? BookingApi();
  late Future<List<BookingHistoryItem>> _future = _loadTrips();
  CustomerTabRefreshNotifier? _tabRefreshNotifier;
  int _tripsTabRefreshVersion = 0;

  Future<List<BookingHistoryItem>> _loadTrips() async {
    final token = await context.read<AuthSession>().getValidAccessToken();
    if (token == null) {
      throw AuthApiException('Please sign in again to load your trips.');
    }
    return _bookingApi.fetchMyBookings(bearerToken: token, limit: 100);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadTrips();
    });
    await _future;
  }

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(CustomerTabIndex.trips);
    if (nextVersion == _tripsTabRefreshVersion) {
      return;
    }
    _tripsTabRefreshVersion = nextVersion;
    setState(() {
      _future = _loadTrips();
    });
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
    _tripsTabRefreshVersion = notifier.versionFor(CustomerTabIndex.trips);
    notifier.addListener(_onTabRefreshTick);
  }

  @override
  void dispose() {
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    super.dispose();
  }

  String _statusLabel(String status) {
    return DrivepalBookingStatusTheme.fromStatus(status).riderLabel;
  }

  String _driverStatusLabel(String status) {
    return DrivepalBookingStatusTheme.fromStatus(status).riderDriverLineLabel;
  }

  String _routeFacts(BookingHistoryItem trip) {
    final bits = <String>[];
    if (trip.durationSeconds != null) {
      final mins = (trip.durationSeconds! / 60).round();
      bits.add(mins < 60 ? '$mins min' : '${mins ~/ 60}h ${mins % 60}m');
    }
    if (trip.distanceMeters != null) {
      final km = trip.distanceMeters! / 1000;
      bits.add(
        km >= 10
            ? '${km.toStringAsFixed(0)} km'
            : '${km.toStringAsFixed(1)} km',
      );
    }
    return bits.isEmpty ? 'Route details pending' : bits.join('  •  ');
  }

  Widget _tripCard(BuildContext context, BookingHistoryItem trip) {
    final statusVisual = DrivepalBookingStatusTheme.fromStatus(trip.status);
    final tt = Theme.of(context).textTheme;
    final routeTextBase = tt.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14.5,
      height: 1.3,
    );
    final requestedAt = trip.requestedAt;
    final requestedAtText =
        requestedAt == null
            ? null
            : '${requestedAt.day.toString().padLeft(2, '0')}/'
                '${requestedAt.month.toString().padLeft(2, '0')} '
                '${requestedAt.hour.toString().padLeft(2, '0')}:'
                '${requestedAt.minute.toString().padLeft(2, '0')}';

    final card = DrivepalElevatedPanel(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(trip.status),
                        style: tt.titleSmall?.copyWith(
                          color: statusVisual.accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Trip ${trip.id.length >= 6 ? trip.id.substring(0, 6) : trip.id}',
                        style: tt.bodySmall?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: DrivepalLocationIcon(
                        icon: Icons.radio_button_checked_rounded,
                        role: DrivepalLocationRole.pickup,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.pickupAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: routeTextBase?.copyWith(
                          color: DrivepalTokens.textHeading,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: DrivepalLocationIcon(
                        icon: Icons.location_on_rounded,
                        role: DrivepalLocationRole.dropoff,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.dropoffAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: routeTextBase?.copyWith(
                          color: DrivepalTokens.textMuted,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver: ${_driverStatusLabel(trip.status)}',
                  style: tt.bodySmall?.copyWith(
                    color: DrivepalTokens.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _routeFacts(trip),
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
                          trip.carTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: tt.bodySmall?.copyWith(color: DrivepalTokens.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
      onTap: () => context.push('/customer/active-trip/${trip.id}'),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
      children: [
        DrivepalFeatureIntroCard(
          icon: Icons.alt_route_rounded,
          title: DrivepalAppShellCopy.riderTripsIntroTitle,
          subtitle: DrivepalAppShellCopy.riderTripsIntroSubtitle,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DrivepalAppShellCopy.riderTripsSectionHistory.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w700,
                    color: DrivepalTokens.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        FutureBuilder<List<BookingHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const DrivepalElevatedPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              final message =
                  snapshot.error is AuthApiException
                      ? (snapshot.error! as AuthApiException).message
                      : 'Could not load trips right now.';
              return DrivepalElevatedPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DrivepalTokens.textBody,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final trips = snapshot.data ?? const <BookingHistoryItem>[];
            if (trips.isEmpty) {
              return DrivepalElevatedPanel(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 18,
                ),
                child: DrivepalEmptyStateBlock(
                  icon: Icons.route_rounded,
                  title: DrivepalAppShellCopy.riderTripsEmptyTitle,
                  body: DrivepalAppShellCopy.riderTripsEmptyBody,
                ),
              );
            }
            return Column(
              children: [
                for (final trip in trips) ...[
                  _tripCard(context, trip),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
