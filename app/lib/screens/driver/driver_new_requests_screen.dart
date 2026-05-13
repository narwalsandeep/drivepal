import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as gmaps_pi;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/booking_maps_repository.dart';
import '../../services/driver_tab_refresh_notifier.dart';
import '../../theme/drivepal_shell_typography.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_fancy_bottom_nav.dart';
import '../../widgets/common/drivepal_location_icon.dart';
import '../../widgets/maps/booking_interactive_map.dart';

class DriverNewRequestsScreen extends StatefulWidget {
  const DriverNewRequestsScreen({
    super.key,
    this.bookingApi,
    this.driverPositionProvider,
    this.locationTickerInterval = const Duration(seconds: 8),
    this.requestFeedRefreshInterval = const Duration(seconds: 12),
  });

  final BookingApi? bookingApi;
  final Future<Position?> Function()? driverPositionProvider;
  final Duration locationTickerInterval;
  final Duration requestFeedRefreshInterval;

  @override
  State<DriverNewRequestsScreen> createState() =>
      _DriverNewRequestsScreenState();
}

enum _DriverTripPanelMode { openRequest, accepted, arriving, inProgress }

class _DriverNewRequestsScreenState extends State<DriverNewRequestsScreen>
    with WidgetsBindingObserver {
  late final BookingApi _bookingApi = widget.bookingApi ?? BookingApi();
  bool _loading = true;
  String? _error;
  List<BookingHistoryItem> _openItems = const <BookingHistoryItem>[];
  BookingHistoryItem? _activeTrip;
  int _selectedIndex = 0;
  bool _actionBusy = false;
  DriverTabRefreshNotifier? _tabRefreshNotifier;
  int _newTabRefreshVersion = 0;
  Timer? _driverLocationTimer;
  Timer? _requestFeedTimer;
  String? _trackingBookingId;
  bool _postingDriverLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startRequestFeedPolling();
  }

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(DriverTabIndex.newRequests);
    if (nextVersion == _newTabRefreshVersion) {
      return;
    }
    _newTabRefreshVersion = nextVersion;
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
    _newTabRefreshVersion = notifier.versionFor(DriverTabIndex.newRequests);
    notifier.addListener(_onTabRefreshTick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _stopDriverLocationLoop();
    _stopRequestFeedPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRequestFeedPolling();
      _load(silent: true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopRequestFeedPolling();
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent || (_activeTrip == null && _openItems.isEmpty)) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _openItems = const <BookingHistoryItem>[];
          _activeTrip = null;
          _loading = false;
          _error = 'Sign in again to view requests.';
        });
        return;
      }
      final rows = await _bookingApi.fetchDriverOpenBookings(
        bearerToken: token,
      );
      final mine = await _bookingApi.fetchDriverBookings(bearerToken: token);
      final active = mine.firstWhere(
        (item) =>
            item.status == 'accepted' ||
            item.status == 'driver_arriving' ||
            item.status == 'in_progress',
        orElse:
            () => const BookingHistoryItem(
              id: '',
              status: '',
              pickupAddress: '',
              dropoffAddress: '',
              carTitle: '',
              paymentMaskedNumber: '',
            ),
      );
      if (!mounted) return;
      setState(() {
        _openItems = rows;
        _activeTrip = active.id.isEmpty ? null : active;
        if (_selectedIndex >= rows.length) {
          _selectedIndex = rows.isEmpty ? 0 : rows.length - 1;
        }
        _loading = false;
      });
      _syncDriverLocationLoop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      _stopDriverLocationLoop();
    }
  }

  void _startRequestFeedPolling() {
    _requestFeedTimer?.cancel();
    _requestFeedTimer = Timer.periodic(
      widget.requestFeedRefreshInterval,
      (_) {
        if (!mounted || _loading || _actionBusy) return;
        _load(silent: true);
      },
    );
  }

  void _stopRequestFeedPolling() {
    _requestFeedTimer?.cancel();
    _requestFeedTimer = null;
  }

  Future<void> _accept(BookingHistoryItem item) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      final res = await _bookingApi.acceptBookingAsDriver(
        bearerToken: token,
        bookingId: item.id,
      );
      if (!mounted) return;
      final acceptedRaw = res['booking'];
      final accepted =
          acceptedRaw is Map<String, dynamic>
              ? BookingHistoryItem.fromJson(acceptedRaw)
              : BookingHistoryItem(
                id: item.id,
                status: 'accepted',
                pickupAddress: item.pickupAddress,
                dropoffAddress: item.dropoffAddress,
                carTitle: item.carTitle,
                paymentMaskedNumber: item.paymentMaskedNumber,
                distanceMeters: item.distanceMeters,
                durationSeconds: item.durationSeconds,
                pickupLatitude: item.pickupLatitude,
                pickupLongitude: item.pickupLongitude,
                dropoffLatitude: item.dropoffLatitude,
                dropoffLongitude: item.dropoffLongitude,
              );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip accepted.')),
      );
      setState(() {
        _activeTrip = accepted;
        _openItems = _openItems.where((row) => row.id != item.id).toList();
        if (_selectedIndex >= _openItems.length) {
          _selectedIndex = _openItems.isEmpty ? 0 : _openItems.length - 1;
        }
      });
      _syncDriverLocationLoop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _pickup() async {
    final active = _activeTrip;
    if (active == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      final res = await _bookingApi.pickupBookingAsDriver(
        bearerToken: token,
        bookingId: active.id,
      );
      if (!mounted) return;
      final updatedRaw = res['booking'];
      final updated =
          updatedRaw is Map<String, dynamic>
              ? BookingHistoryItem.fromJson(updatedRaw)
              : BookingHistoryItem(
                id: active.id,
                status: 'in_progress',
                pickupAddress: active.pickupAddress,
                dropoffAddress: active.dropoffAddress,
                carTitle: active.carTitle,
                paymentMaskedNumber: active.paymentMaskedNumber,
                distanceMeters: active.distanceMeters,
                durationSeconds: active.durationSeconds,
                pickupLatitude: active.pickupLatitude,
                pickupLongitude: active.pickupLongitude,
                dropoffLatitude: active.dropoffLatitude,
                dropoffLongitude: active.dropoffLongitude,
              );
      setState(() => _activeTrip = updated);
      _syncDriverLocationLoop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _arrive() async {
    final active = _activeTrip;
    if (active == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      final res = await _bookingApi.arriveBookingAsDriver(
        bearerToken: token,
        bookingId: active.id,
      );
      if (!mounted) return;
      final updatedRaw = res['booking'];
      final updated =
          updatedRaw is Map<String, dynamic>
              ? BookingHistoryItem.fromJson(updatedRaw)
              : BookingHistoryItem(
                id: active.id,
                status: 'driver_arriving',
                pickupAddress: active.pickupAddress,
                dropoffAddress: active.dropoffAddress,
                carTitle: active.carTitle,
                paymentMaskedNumber: active.paymentMaskedNumber,
                distanceMeters: active.distanceMeters,
                durationSeconds: active.durationSeconds,
                pickupLatitude: active.pickupLatitude,
                pickupLongitude: active.pickupLongitude,
                dropoffLatitude: active.dropoffLatitude,
                dropoffLongitude: active.dropoffLongitude,
              );
      setState(() => _activeTrip = updated);
      _syncDriverLocationLoop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _finish() async {
    final active = _activeTrip;
    if (active == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      await _bookingApi.finishBookingAsDriver(
        bearerToken: token,
        bookingId: active.id,
      );
      if (!mounted) return;
      setState(() => _activeTrip = null);
      _stopDriverLocationLoop();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride marked as finished.')));
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _cancelActive() async {
    final active = _activeTrip;
    if (active == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      await _bookingApi.cancelBookingAsDriver(
        bearerToken: token,
        bookingId: active.id,
      );
      if (!mounted) return;
      setState(() => _activeTrip = null);
      _stopDriverLocationLoop();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Trip released for reassignment.')),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  bool _shouldTrackDriverLocation(BookingHistoryItem? trip) {
    if (trip == null) return false;
    return trip.status == 'accepted' ||
        trip.status == 'driver_arriving' ||
        trip.status == 'in_progress';
  }

  void _syncDriverLocationLoop() {
    final active = _activeTrip;
    if (!_shouldTrackDriverLocation(active)) {
      _stopDriverLocationLoop();
      return;
    }
    final bookingId = active!.id;
    if (_trackingBookingId == bookingId && _driverLocationTimer != null) {
      return;
    }
    _trackingBookingId = bookingId;
    _driverLocationTimer?.cancel();
    _publishDriverLocation();
    _driverLocationTimer = Timer.periodic(
      widget.locationTickerInterval,
      (_) => _publishDriverLocation(),
    );
  }

  void _stopDriverLocationLoop() {
    _driverLocationTimer?.cancel();
    _driverLocationTimer = null;
    _trackingBookingId = null;
  }

  Future<void> _publishDriverLocation() async {
    if (!mounted || _postingDriverLocation) {
      return;
    }
    final bookingId = _trackingBookingId;
    if (bookingId == null || bookingId.isEmpty) {
      return;
    }
    _postingDriverLocation = true;
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted || token == null) return;
      final customPositionProvider = widget.driverPositionProvider;
      Position? pos;
      if (customPositionProvider != null) {
        pos = await customPositionProvider();
        if (pos == null) return;
      } else {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
      }
      await _bookingApi.updateDriverLocation(
        bookingId: bookingId,
        latitude: pos!.latitude,
        longitude: pos!.longitude,
        accuracyMeters: pos!.accuracy,
        bearerToken: token,
      );
    } catch (_) {
      // Keep location publishing non-blocking during an active trip.
    } finally {
      _postingDriverLocation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final current = _activeTrip ?? (_openItems.isNotEmpty ? _openItems[_selectedIndex] : null);
    if (current != null) {
      final mode = switch (current.status) {
        'in_progress' => _DriverTripPanelMode.inProgress,
        'driver_arriving' => _DriverTripPanelMode.arriving,
        'accepted' => _DriverTripPanelMode.accepted,
        _ => _DriverTripPanelMode.openRequest,
      };
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      final requestCardBottom = math.max(
        0.0,
        DrivepalFancyBottomNav.reservedOuterHeight(context) - safeBottom - 52,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _DriverRequestMap(key: ValueKey(current.id), item: current),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  if (_error != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 8,
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DrivepalTokens.textDanger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: requestCardBottom,
                    child: _DriverRequestPager(
                      item: current,
                      mode: mode,
                      currentIndex: _selectedIndex,
                      totalCount: _openItems.length,
                      busy: _actionBusy,
                      onAccept: () => _accept(current),
                      onArrive: _arrive,
                      onPickup: _pickup,
                      onFinish: _finish,
                      onCancel: _cancelActive,
                      onPrev:
                          _activeTrip == null && _selectedIndex > 0
                              ? () => setState(() => _selectedIndex--)
                              : null,
                      onNext:
                          _activeTrip == null &&
                                  _selectedIndex < _openItems.length - 1
                              ? () => setState(() => _selectedIndex++)
                              : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrivepalTokens.textDanger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const _DriverEmptyState(
            title: 'No open requests right now',
            subtitle:
                'Pull to refresh anytime. This view also refreshes automatically.',
          ),
        ],
      ),
    );
  }
}

class _DriverRequestPager extends StatelessWidget {
  const _DriverRequestPager({
    required this.item,
    required this.mode,
    required this.currentIndex,
    required this.totalCount,
    required this.busy,
    required this.onAccept,
    required this.onArrive,
    required this.onPickup,
    required this.onFinish,
    required this.onCancel,
    required this.onPrev,
    required this.onNext,
  });

  final BookingHistoryItem item;
  final _DriverTripPanelMode mode;
  final int currentIndex;
  final int totalCount;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onArrive;
  final VoidCallback onPickup;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  String _distanceLabel(int? distanceMeters) {
    if (distanceMeters == null) return 'Distance pending';
    final km = distanceMeters / 1000;
    return km >= 10
        ? '${km.toStringAsFixed(0)} km'
        : '${km.toStringAsFixed(1)} km';
  }

  String _durationLabel(int? durationSeconds) {
    if (durationSeconds == null) return 'ETA pending';
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  String? _scheduleLabel(DateTime? scheduledFor) {
    if (scheduledFor == null) {
      return null;
    }
    final local = scheduledFor.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Scheduled: $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduledLabel = _scheduleLabel(item.scheduledFor);
    final routeFacts = <String>[
      if (item.carTitle.trim().isNotEmpty) item.carTitle,
      _distanceLabel(item.distanceMeters),
      _durationLabel(item.durationSeconds),
    ];
    return Container(
      decoration: BoxDecoration(
        color: DrivepalTokens.bgCard.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mode == _DriverTripPanelMode.openRequest
                        ? 'New Trip'
                        : 'Current Trip',
                    style: DrivepalShellTypography.elevatedInlineTitle(
                      theme.textTheme,
                    ).copyWith(
                      fontSize: 18,
                      color: DrivepalTokens.textHeading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (mode == _DriverTripPanelMode.openRequest)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (scheduledLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: DrivepalTokens.bgPrimary,
                            borderRadius: BorderRadius.circular(
                              DrivepalTokens.radiusInput,
                            ),
                          ),
                          child: Text(
                            scheduledLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: DrivepalTokens.textOnPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      if (scheduledLabel != null) const SizedBox(width: 8),
                      Text(
                        '${currentIndex + 1} of $totalCount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (mode == _DriverTripPanelMode.openRequest) ...[
              const SizedBox(height: 10),
              Text(
                routeFacts.join('  •  '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: DrivepalTokens.textBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 12),
            _RequestAddressRow(
              label: 'Pickup',
              value: item.pickupAddress,
              icon: Icons.radio_button_checked_rounded,
              role: DrivepalLocationRole.pickup,
            ),
            const SizedBox(height: 14),
            _RequestAddressRow(
              label: 'Drop-off',
              value: item.dropoffAddress,
              icon: Icons.location_on_rounded,
              role: DrivepalLocationRole.dropoff,
            ),
            const SizedBox(height: 12),
            if (busy)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: DrivepalTokens.bgPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Accepting request...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DrivepalTokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (busy) const SizedBox(height: 4),
            const SizedBox(height: 18),
            _DriverBottomActionBar(
              mode: mode,
              busy: busy,
              onAccept: onAccept,
              onArrive: onArrive,
              onPickup: onPickup,
              onFinish: onFinish,
              onCancel: onCancel,
              onPrev: onPrev,
              onNext: onNext,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverBottomActionBar extends StatelessWidget {
  const _DriverBottomActionBar({
    required this.mode,
    required this.busy,
    required this.onAccept,
    required this.onArrive,
    required this.onPickup,
    required this.onFinish,
    required this.onCancel,
    required this.onPrev,
    required this.onNext,
    this.compact = false,
  });

  final _DriverTripPanelMode mode;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onArrive;
  final VoidCallback onPickup;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const buttonHeight = 52.0;
    if (mode == _DriverTripPanelMode.accepted) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: DrivepalTokens.textDanger,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: FilledButton(
                onPressed: busy ? null : onArrive,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: DrivepalTokens.bgPrimaryHover,
                  foregroundColor: DrivepalTokens.textOnPrimary,
                ),
                child: Text(busy ? 'Working...' : 'Arrived'),
              ),
            ),
          ),
        ],
      );
    }

    if (mode == _DriverTripPanelMode.arriving) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: OutlinedButton(
                onPressed: busy ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: DrivepalTokens.textDanger,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: FilledButton(
                onPressed: busy ? null : onPickup,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: DrivepalTokens.bgPrimaryHover,
                  foregroundColor: DrivepalTokens.textOnPrimary,
                ),
                child: Text(busy ? 'Working...' : 'Start ride'),
              ),
            ),
          ),
        ],
      );
    }

    if (mode == _DriverTripPanelMode.inProgress) {
      return SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onFinish,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: DrivepalTokens.bgPrimaryHover,
            foregroundColor: DrivepalTokens.textOnPrimary,
          ),
          child: Text(busy ? 'Working...' : 'Ride finished'),
        ),
      );
    }

    final row = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: busy ? null : onPrev,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 30),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: buttonHeight,
            child: FilledButton(
              onPressed: busy ? null : onAccept,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: DrivepalTokens.bgPrimaryHover,
                foregroundColor: DrivepalTokens.textOnPrimary,
              ),
              child: Text(busy ? 'Accepting...' : 'Accept'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: busy ? null : onNext,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 30),
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return row;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: DrivepalTokens.bgCard.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
        border: Border.all(color: DrivepalTokens.borderCard),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -12,
            color: DrivepalTokens.textHeading.withValues(alpha: 0.28),
          ),
        ],
      ),
      child: row,
    );
  }
}

class _DriverRequestMap extends StatefulWidget {
  const _DriverRequestMap({super.key, required this.item});

  final BookingHistoryItem item;

  @override
  State<_DriverRequestMap> createState() => _DriverRequestMapState();
}

class _DriverRequestMapState extends State<_DriverRequestMap> {
  GoogleMapController? _controller;
  final BookingMapsRepository _maps = HttpBookingMapsRepository();
  List<LatLng> _routePoints = const <LatLng>[];
  int _routeLoadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadRouteGeometry();
  }

  @override
  void didUpdateWidget(covariant _DriverRequestMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _loadRouteGeometry();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  Future<void> _loadRouteGeometry() async {
    final pLat = widget.item.pickupLatitude;
    final pLng = widget.item.pickupLongitude;
    final dLat = widget.item.dropoffLatitude;
    final dLng = widget.item.dropoffLongitude;

    if (pLat == null || pLng == null || dLat == null || dLng == null) {
      if (mounted) {
        setState(() => _routePoints = const <LatLng>[]);
      }
      return;
    }

    final seq = ++_routeLoadSeq;
    final origin = LatLng(pLat, pLng);
    final destination = LatLng(dLat, dLng);

    try {
      final route = await _maps.directions(origin, destination);
      if (!mounted || seq != _routeLoadSeq) return;
      final points = route.points.length >= 2
          ? route.points
          : <LatLng>[origin, destination];
      setState(() => _routePoints = points);
    } catch (_) {
      if (!mounted || seq != _routeLoadSeq) return;
      setState(() => _routePoints = <LatLng>[origin, destination]);
    }

    if (mounted && seq == _routeLoadSeq) {
      _fitBounds();
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    final pLat = widget.item.pickupLatitude;
    final pLng = widget.item.pickupLongitude;
    final dLat = widget.item.dropoffLatitude;
    final dLng = widget.item.dropoffLongitude;
    if (pLat != null && pLng != null) {
      markers.add(
        gmaps_pi.AdvancedMarker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pLat, pLng),
          icon: const gmaps_pi.PinConfig(
            backgroundColor: Color(0xFF1E88E5),
            glyph: gmaps_pi.CircleGlyph(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
    }
    if (dLat != null && dLng != null) {
      markers.add(
        gmaps_pi.AdvancedMarker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dLat, dLng),
          icon: const gmaps_pi.PinConfig(
            backgroundColor: Color(0xFF2E7D32),
            glyph: gmaps_pi.CircleGlyph(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylines() {
    final pLat = widget.item.pickupLatitude;
    final pLng = widget.item.pickupLongitude;
    final dLat = widget.item.dropoffLatitude;
    final dLng = widget.item.dropoffLongitude;
    if (pLat == null || pLng == null || dLat == null || dLng == null) {
      return const <Polyline>{};
    }
    final points = _routePoints.length >= 2
        ? _routePoints
        : <LatLng>[LatLng(pLat, pLng), LatLng(dLat, dLng)];
    return {
      Polyline(
        polylineId: const PolylineId('request_line'),
        color: DrivepalTokens.bgPrimary,
        width: 5,
        points: points,
      ),
    };
  }

  Future<void> _fitBounds() async {
    final ctl = _controller;
    final pLat = widget.item.pickupLatitude;
    final pLng = widget.item.pickupLongitude;
    final dLat = widget.item.dropoffLatitude;
    final dLng = widget.item.dropoffLongitude;
    if (ctl == null || pLat == null || pLng == null) return;
    final liftPixels = (MediaQuery.sizeOf(context).height * 0.22).clamp(
      140.0,
      320.0,
    );

    Future<void> apply(CameraUpdate update) async {
      try {
        await ctl.animateCamera(update);
      } catch (_) {
        try {
          await ctl.moveCamera(update);
        } catch (_) {}
      }
    }

    Future<void> applyLift() async {
      try {
        await ctl.animateCamera(CameraUpdate.scrollBy(0, liftPixels));
      } catch (_) {
        try {
          await ctl.moveCamera(CameraUpdate.scrollBy(0, liftPixels));
        } catch (_) {}
      }
    }

    if (dLat == null || dLng == null) {
      await apply(CameraUpdate.newLatLngZoom(LatLng(pLat, pLng), 13));
      await applyLift();
      return;
    }

    final south = math.min(pLat, dLat);
    final north = math.max(pLat, dLat);
    final west = math.min(pLng, dLng);
    final east = math.max(pLng, dLng);
    final latPad = (north - south).abs() < 0.005 ? 0.005 : 0;
    final lngPad = (east - west).abs() < 0.005 ? 0.005 : 0;
    final bounds = LatLngBounds(
      southwest: LatLng(south - latPad, west - lngPad),
      northeast: LatLng(north + latPad, east + lngPad),
    );
    await apply(CameraUpdate.newLatLngBounds(bounds, 56));
    await applyLift();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        widget.item.pickupLatitude != null &&
        widget.item.pickupLongitude != null;
    final topPadding = MediaQuery.paddingOf(context).top + 72;
    if (!hasLocation) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
        child: Center(
          child: Text(
            'Map preview unavailable for this request',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrivepalTokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: true,
      child: BookingInteractiveMap(
        interactive: false,
        markers: _markers(),
        polylines: _polylines(),
        padding: EdgeInsets.only(top: topPadding),
        onControllerReady: (controller) {
          _controller = controller;
          _fitBounds();
        },
      ),
    );
  }
}

class _RequestAddressRow extends StatelessWidget {
  const _RequestAddressRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.role,
  });

  final String label;
  final String value;
  final IconData icon;
  final DrivepalLocationRole role;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final routeTextStyle = GoogleFonts.inter(
      textStyle: DrivepalShellTypography.elevatedInlineTitle(typography),
      fontSize: 17,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: DrivepalTokens.textHeading,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: DrivepalLocationIcon(icon: icon, role: role, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: typography.labelMedium?.copyWith(
                  color: DrivepalTokens.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: routeTextStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverEmptyState extends StatelessWidget {
  const _DriverEmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_outlined, size: 30),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: DrivepalTokens.textMuted),
          ),
        ],
      ),
    );
  }
}
