import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/customer_tab_refresh_notifier.dart';
import '../../theme/drivepal_app_shell_copy.dart';
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
  final Set<String> _cancellingTripIds = <String>{};
  CustomerTabRefreshNotifier? _tabRefreshNotifier;
  int _tripsTabRefreshVersion = 0;

  static const List<_CancelReasonOption> _cancelReasonOptions = [
    _CancelReasonOption('change_of_plans', 'Change of plans'),
    _CancelReasonOption('driver_delay', 'Driver is taking too long'),
    _CancelReasonOption('pickup_changed', 'Pickup location changed'),
    _CancelReasonOption('booked_by_mistake', 'Booked by mistake'),
    _CancelReasonOption('fare_concern', 'Price concern'),
    _CancelReasonOption('other', 'Other reason'),
  ];

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

  Future<void> _onTapCancelTrip(BookingHistoryItem trip) async {
    if (_cancellingTripIds.contains(trip.id)) return;
    final request = await _showCancelTripModal();
    if (!mounted || request == null) return;

    setState(() {
      _cancellingTripIds.add(trip.id);
    });
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        _showBottomMessage('Please sign in again to cancel this trip.');
        return;
      }
      await _bookingApi.cancelBooking(
        bookingId: trip.id,
        reasonCode: request.reasonCode,
        note: request.note,
        bearerToken: token,
      );
      if (!mounted) return;
      _showBottomMessage('Trip cancelled successfully.');
      await _refresh();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showBottomMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showBottomMessage('Could not cancel trip. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _cancellingTripIds.remove(trip.id);
        });
      }
    }
  }

  Future<_CancelTripRequest?> _showCancelTripModal() async {
    String selectedReason = _cancelReasonOptions.first.code;
    final noteCtrl = TextEditingController();
    try {
      return await showModalBottomSheet<_CancelTripRequest>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    drivepalModalBottomInset(ctx),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DrivepalTokens.bgCard,
                      borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                      border: Border.all(
                        color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Cancel trip',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              color: DrivepalTokens.textHeading,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedReason,
                            items:
                                _cancelReasonOptions
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item.code,
                                        child: Text(item.label),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => selectedReason = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: noteCtrl,
                            maxLength: 280,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Additional details (optional)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(
                                _CancelTripRequest(
                                  reasonCode: selectedReason,
                                  note: noteCtrl.text,
                                ),
                              );
                            },
                            child: const Text('Confirm cancellation'),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Keep trip'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  void _showBottomMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'Waiting for driver';
      case 'accepted':
        return 'Driver accepted';
      case 'driver_arriving':
        return 'Driver arriving';
      case 'in_progress':
        return 'Ride in progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _driverStatusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'No driver yet';
      case 'accepted':
        return 'Driver assigned';
      case 'driver_arriving':
        return 'Driver arriving';
      case 'in_progress':
        return 'With driver';
      case 'completed':
        return 'Trip finished';
      case 'cancelled':
        return 'Trip cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
      case 'driver_arriving':
        return Icons.local_taxi_rounded;
      case 'in_progress':
        return Icons.route_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _statusAccentColor(String status) {
    return status == 'cancelled'
        ? DrivepalTokens.textDanger
        : DrivepalTokens.bgPrimary;
  }

  Color _statusSurfaceColor(String status) {
    return status == 'cancelled'
        ? DrivepalTokens.dangerSoftBg
        : DrivepalTokens.bgPrimary.withValues(alpha: 0.1);
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
                    color: _statusSurfaceColor(trip.status),
                  ),
                  child: Icon(
                    _statusIcon(trip.status),
                    size: 16,
                    color: _statusAccentColor(trip.status),
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
                          color:
                              trip.status == 'cancelled'
                                  ? DrivepalTokens.textDanger
                                  : DrivepalTokens.textHeading,
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
                if (trip.canCancel) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap:
                          _cancellingTripIds.contains(trip.id)
                              ? null
                              : () => _onTapCancelTrip(trip),
                      child: Text(
                        _cancellingTripIds.contains(trip.id)
                            ? 'Cancelling...'
                            : 'Tap to cancel',
                        style: tt.bodySmall?.copyWith(
                          color: DrivepalTokens.textDanger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

class _CancelReasonOption {
  const _CancelReasonOption(this.code, this.label);

  final String code;
  final String label;
}

class _CancelTripRequest {
  const _CancelTripRequest({required this.reasonCode, this.note});

  final String reasonCode;
  final String? note;
}
