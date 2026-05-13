import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/booking_maps_repository.dart';
import '../../theme/drivepal_booking_status_theme.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';
import '../../widgets/maps/booking_interactive_map.dart';

class RiderActiveTripScreen extends StatefulWidget {
  const RiderActiveTripScreen({
    super.key,
    required this.bookingId,
    this.bookingApi,
  });

  final String bookingId;
  final BookingApi? bookingApi;

  @override
  State<RiderActiveTripScreen> createState() => _RiderActiveTripScreenState();
}

class _RiderActiveTripScreenState extends State<RiderActiveTripScreen> {
  late final BookingApi _bookingApi = widget.bookingApi ?? BookingApi();
  final BookingMapsRepository _mapsRepository = HttpBookingMapsRepository();
  BookingTrackingSnapshot? _snapshot;
  List<LatLng> _routePoints = const <LatLng>[];
  String? _routeCacheKey;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  Timer? _pollTimer;

  static const List<_CancelReasonOption> _cancelReasonOptions = [
    _CancelReasonOption('change_of_plans', 'Change of plans'),
    _CancelReasonOption('driver_delay', 'Driver is taking too long'),
    _CancelReasonOption('pickup_changed', 'Pickup location changed'),
    _CancelReasonOption('booked_by_mistake', 'Booked by mistake'),
    _CancelReasonOption('fare_concern', 'Price concern'),
    _CancelReasonOption('other', 'Other reason'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTracking(showLoader: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _loadTracking(showLoader: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTracking({required bool showLoader}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again to continue tracking this trip.';
        });
        return;
      }
      final snapshot = await _bookingApi.fetchTrackingForBooking(
        bookingId: widget.bookingId,
        bearerToken: token,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
      _syncRoutePolyline(snapshot.booking);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not refresh tracking right now.';
      });
    }
  }

  String _statusLabel(String status) {
    if (status == 'requested') {
      return 'Finding a driver';
    }
    if (status == 'completed') {
      return 'Ride completed';
    }
    if (status == 'cancelled') {
      return 'Ride cancelled';
    }
    return DrivepalBookingStatusTheme.fromStatus(status).riderLabel;
  }

  void _syncRoutePolyline(BookingHistoryItem booking) {
    final pickupLat = booking.pickupLatitude;
    final pickupLng = booking.pickupLongitude;
    final dropoffLat = booking.dropoffLatitude;
    final dropoffLng = booking.dropoffLongitude;
    if (pickupLat == null ||
        pickupLng == null ||
        dropoffLat == null ||
        dropoffLng == null) {
      if (_routePoints.isNotEmpty) {
        setState(() {
          _routePoints = const <LatLng>[];
          _routeCacheKey = null;
        });
      }
      return;
    }

    final nextKey = [
      pickupLat.toStringAsFixed(6),
      pickupLng.toStringAsFixed(6),
      dropoffLat.toStringAsFixed(6),
      dropoffLng.toStringAsFixed(6),
    ].join(':');
    if (_routeCacheKey == nextKey && _routePoints.length >= 2) {
      return;
    }
    _routeCacheKey = nextKey;
    final origin = LatLng(pickupLat, pickupLng);
    final destination = LatLng(dropoffLat, dropoffLng);
    _mapsRepository
        .directions(origin, destination)
        .then((result) {
          if (!mounted) return;
          if (_routeCacheKey != nextKey) return;
          setState(() {
            _routePoints = result.points.length >= 2
                ? result.points
                : <LatLng>[origin, destination];
          });
        })
        .catchError((_) {
          if (!mounted) return;
          if (_routeCacheKey != nextKey) return;
          setState(() {
            _routePoints = <LatLng>[origin, destination];
          });
        });
  }

  Set<Marker> _markersForSnapshot(BookingTrackingSnapshot snapshot) {
    final booking = snapshot.booking;
    final markers = <Marker>{};
    if (booking.pickupLatitude != null && booking.pickupLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(booking.pickupLatitude!, booking.pickupLongitude!),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      );
    }
    if (booking.dropoffLatitude != null && booking.dropoffLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(booking.dropoffLatitude!, booking.dropoffLongitude!),
          infoWindow: const InfoWindow(title: 'Drop-off'),
        ),
      );
    }
    final driver = snapshot.driverLocation;
    if (driver != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver.latitude, driver.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
      );
    }
    return markers;
  }

  Future<void> _onTapCancel() async {
    if (_cancelling) return;
    final booking = _snapshot?.booking;
    if (booking == null || !booking.canCancel) return;
    final request = await _showCancelTripModal();
    if (!mounted || request == null) return;

    setState(() => _cancelling = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        _showBottomMessage('Please sign in again to cancel this trip.');
        return;
      }
      await _bookingApi.cancelBooking(
        bookingId: booking.id,
        reasonCode: request.reasonCode,
        note: request.note,
        bearerToken: token,
      );
      await _loadTracking(showLoader: false);
      if (!mounted) return;
      _showBottomMessage('Trip cancelled successfully.');
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showBottomMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showBottomMessage('Could not cancel trip. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
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
                            decoration: const InputDecoration(labelText: 'Reason'),
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

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return DrivepalStandalonePageScaffold(
      title: 'Active trip',
      bottomNavigationBar:
          snapshot != null
              ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DrivepalTokens.bgCard,
                      borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                      border: Border.all(
                        color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Builder(
                        builder: (context) {
                          final statusVisual = DrivepalBookingStatusTheme.fromStatus(
                            snapshot.booking.status,
                          );
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Status: ${_statusLabel(snapshot.booking.status)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: statusVisual.accentColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed:
                                    (snapshot.booking.canCancel && !_cancelling)
                                        ? _onTapCancel
                                        : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: DrivepalTokens.danger,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(148, 44),
                                ),
                                icon: const Icon(Icons.cancel_rounded),
                                label: Text(
                                  _cancelling
                                      ? 'Cancelling...'
                                      : (snapshot.booking.canCancel
                                          ? 'Cancel trip'
                                          : 'Cannot cancel'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )
              : null,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: DrivepalElevatedPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        onPressed: () => _loadTracking(showLoader: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : snapshot == null
              ? const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: DrivepalElevatedPanel(
                  child: Text('Trip tracking is unavailable right now.'),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final statusVisual = DrivepalBookingStatusTheme.fromStatus(
                        snapshot.booking.status,
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DrivepalElevatedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusLabel(snapshot.booking.status),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: statusVisual.accentColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snapshot.booking.pickupAddress,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: DrivepalTokens.textBody,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snapshot.booking.dropoffAddress,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: DrivepalTokens.textMuted),
                              ),
                              if (snapshot.driverLocation?.recordedAt != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Driver location updated at '
                                  '${snapshot.driverLocation!.recordedAt!.hour.toString().padLeft(2, '0')}:'
                                  '${snapshot.driverLocation!.recordedAt!.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: DrivepalTokens.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            DrivepalTokens.radiusCard,
                          ),
                          border: Border.all(
                            color: DrivepalTokens.borderCard.withValues(
                              alpha: 0.95,
                            ),
                            width: 1.25,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DrivepalTokens.radiusCard,
                          ),
                          child: BookingInteractiveMap(
                            markers: _markersForSnapshot(snapshot),
                    polylines: _routePoints.length >= 2
                        ? <Polyline>{
                            Polyline(
                              polylineId: const PolylineId('active-trip-route'),
                              points: _routePoints,
                              color: DrivepalTokens.bgPrimary,
                              width: 5,
                            ),
                          }
                        : const <Polyline>{},
                            interactive: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
