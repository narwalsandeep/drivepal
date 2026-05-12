import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    as gmaps_pi;
import 'package:provider/provider.dart';

import '../../config/booking_map_defaults.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/booking_api.dart';
import '../../services/booking_maps_repository.dart';
import '../../services/payment_methods_api.dart';
import '../../services/payment_methods_store.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_tokens.dart';
import '../../widgets/booking/drivepal_booking_sheet.dart';
import '../../widgets/booking/booking_location_wizard.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/maps/booking_interactive_map.dart';

enum _BookWizardStep { pickup, dropoff, review }

class _CarTypeOption {
  const _CarTypeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.seats,
    required this.icon,
    required this.pricePerKmGbp,
  });

  final String id;
  final String title;
  final String subtitle;
  final int seats;
  final IconData icon;
  final double pricePerKmGbp;
}

class _PaymentPickerResult {
  const _PaymentPickerResult({this.card, this.requestAddCard = false});

  final PaymentMethodCard? card;
  final bool requestAddCard;
}

class _ScheduleOption {
  const _ScheduleOption({required this.label, required this.minutesFromNow});

  final String label;
  final int? minutesFromNow;
}

/// Multi-step book flow: pickup → destination → summary, with debounced geocode.
class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key, this.mapsRepository, this.bookingApi});

  /// Injected in tests ([HttpBookingMapsRepository] is default in production).
  final BookingMapsRepository? mapsRepository;
  final BookingApi? bookingApi;

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  late final BookingMapsRepository _maps =
      widget.mapsRepository ?? HttpBookingMapsRepository();
  late final BookingApi _bookingApi = widget.bookingApi ?? BookingApi();

  final TextEditingController _pickupCtrl = TextEditingController();
  final TextEditingController _dropoffCtrl = TextEditingController();

  GoogleMapController? _mapCtl;
  Timer? _pickDeb;
  Timer? _dropDeb;
  int _pickSeq = 0;
  int _dropSeq = 0;

  _BookWizardStep _step = _BookWizardStep.pickup;

  bool _pickBusy = false;
  bool _dropBusy = false;
  bool _routeBusy = false;
  bool _pickupCurrentLocationBusy = false;

  LatLng? _pickLl;
  LatLng? _dropLl;
  List<LatLng> _routePts = [];
  BookingRouteResult? _routeResult;
  _CarTypeOption? _selectedCarType;
  PaymentMethodCard? _selectedPaymentCard;
  _ScheduleOption _selectedScheduleOption = _scheduleOptions.first;

  bool get _canNextPickup =>
      _pickupCtrl.text.trim().isNotEmpty &&
      !_advancePickupBusy &&
      !_pickupCurrentLocationBusy;

  bool get _canNextDropoff =>
      _dropoffCtrl.text.trim().isNotEmpty && !_advanceDropoffBusy;

  bool get _canRequestRide =>
      _pickupCtrl.text.trim().isNotEmpty &&
      _dropoffCtrl.text.trim().isNotEmpty &&
      !_advanceRequestRideBusy;

  bool _advancePickupBusy = false;
  bool _advanceDropoffBusy = false;
  bool _advanceRequestRideBusy = false;
  bool _paymentProgressDialogVisible = false;
  String? _pickupLookupMessage;
  String? _dropoffLookupMessage;
  bool _paymentBusy = false;
  bool _carOptionsLoading = false;
  String? _carOptionsError;
  String _carCurrencyCode = 'GBP';
  List<_CarTypeOption> _carTypeOptions = <_CarTypeOption>[];
  static const List<_ScheduleOption> _scheduleOptions = <_ScheduleOption>[
    _ScheduleOption(label: 'Now', minutesFromNow: null),
    _ScheduleOption(label: 'In 10 minutes', minutesFromNow: 10),
    _ScheduleOption(label: 'In 20 minutes', minutesFromNow: 20),
    _ScheduleOption(label: 'In 30 minutes', minutesFromNow: 30),
    _ScheduleOption(label: 'In 1 hour', minutesFromNow: 60),
    _ScheduleOption(label: 'In 2 hours', minutesFromNow: 120),
  ];

  static const double _currentPickupAcceptedAccuracyMeters = 75;

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000;
    return km >= 10
        ? '${km.toStringAsFixed(0)} km'
        : '${km.toStringAsFixed(1)} km';
  }

  String _formatCurrency(double value) {
    if (_carCurrencyCode == 'GBP') {
      return '£${value.toStringAsFixed(2)}';
    }
    return '${value.toStringAsFixed(2)} $_carCurrencyCode';
  }

  double? _estimateFareGbp(_CarTypeOption option) {
    final meters = _routeResult?.distanceMeters;
    if (meters == null || meters <= 0) {
      return null;
    }
    final km = meters / 1000;
    return km * option.pricePerKmGbp;
  }

  IconData _iconForCarOption(String carId) {
    switch (carId) {
      case 'sedan4':
        return Icons.directions_car_filled_rounded;
      case 'suv6':
        return Icons.directions_car_rounded;
      case 'mpv5':
      case 'van7':
      case 'van8':
        return Icons.airport_shuttle_rounded;
      default:
        return Icons.directions_car_filled_rounded;
    }
  }

  double _selectionSheetMaxHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final shellTopClearance = drivepalModalTopInset(context);
    final preferred = screenHeight * 0.78;
    final remaining = screenHeight - shellTopClearance - 8;
    final bounded = remaining < preferred ? remaining : preferred;
    return bounded < 220 ? 220 : bounded;
  }

  String? get _routePrimarySummary {
    if (_routeBusy) return DrivepalAppShellCopy.riderBookRouteCalculating;
    final r = _routeResult;
    if (r == null) return null;
    final bits = <String>[];
    if (r.durationSeconds != null) {
      bits.add(_formatDuration(r.durationSeconds!));
    }
    if (r.distanceMeters != null) {
      bits.add(_formatDistance(r.distanceMeters!));
    }
    return bits.isEmpty ? null : bits.join('  •  ');
  }

  String? get _routeSecondarySummary {
    final r = _routeResult;
    if (r == null) return null;
    final traffic = r.durationInTrafficSeconds;
    if (traffic == null) return null;
    final normal = r.durationSeconds;
    if (normal != null && traffic <= normal) return null;
    return '${DrivepalAppShellCopy.riderBookRouteTrafficLabel}: ${_formatDuration(traffic)}';
  }

  String get _reviewCtaLabel =>
      _selectedCarType == null
          ? 'Select car'
          : (_selectedPaymentCard == null
              ? 'Select payment method'
              : 'Finish booking');

  String get _reviewCtaSemantics =>
      _selectedCarType == null
          ? 'Select car type for this ride'
          : (_selectedPaymentCard == null
              ? 'Select payment method for this ride'
              : 'Finish booking and notify drivers');

  IconData get _reviewCtaIcon =>
      _selectedPaymentCard == null
          ? Icons.arrow_forward_rounded
          : Icons.check_circle_rounded;

  String? get _selectedCarSummary =>
      _selectedCarType == null
          ? null
          : (() {
            final selectedCar = _selectedCarType!;
            final estimate = _estimateFareGbp(selectedCar);
            final perKm = '${_formatCurrency(selectedCar.pricePerKmGbp)}/km';
            if (estimate == null) {
              return '${selectedCar.title} (${selectedCar.seats} seats) • $perKm';
            }
            return '${selectedCar.title} (${selectedCar.seats} seats) • '
                '$perKm • Est ${_formatCurrency(estimate)}';
          })();

  String? get _selectedPaymentSummary =>
      _selectedPaymentCard == null
          ? null
          : '${_selectedPaymentCard!.brand} ${_selectedPaymentCard!.maskedNumber}';

  String get _selectedScheduleSummary {
    final minutes = _selectedScheduleOption.minutesFromNow;
    if (minutes == null) {
      return 'Pickup time: Now';
    }
    return 'Pickup time: ${_selectedScheduleOption.label}';
  }

  Future<void> _onEditSelectedCar() async {
    await _ensureCarOptionsLoaded();
    if (!mounted) return;
    final selected = await _showCarTypePicker();
    if (!mounted || selected == null) return;
    setState(() => _selectedCarType = selected);
  }

  Future<void> _onEditSelectedPaymentCard() async {
    final selected = await _pickPaymentCard();
    if (!mounted || selected == null) return;
    setState(() => _selectedPaymentCard = selected);
  }

  Future<void> _onEditSchedule() async {
    final selected = await showModalBottomSheet<_ScheduleOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              drivepalModalTopInset(ctx),
              12,
              drivepalModalBottomInset(ctx),
            ),
            child: DrivepalBookingSheet(
              title: 'Choose pickup time',
              subtitle: 'Request now or schedule up to 2 hours ahead.',
              maxHeight: _selectionSheetMaxHeight(ctx),
              body: Column(
                children: [
                  for (final option in _scheduleOptions) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () => Navigator.of(ctx).pop(option),
                      leading: Icon(
                        option.minutesFromNow == null
                            ? Icons.flash_on_rounded
                            : Icons.schedule_rounded,
                      ),
                      title: Text(option.label),
                      trailing:
                          _selectedScheduleOption.label == option.label
                              ? const Icon(Icons.check_rounded)
                              : null,
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _selectedScheduleOption = selected);
  }

  Future<void> _ensureCarOptionsLoaded() async {
    if (_carTypeOptions.isNotEmpty || _carOptionsLoading) {
      return;
    }
    setState(() {
      _carOptionsLoading = true;
      _carOptionsError = null;
    });
    try {
      String? token;
      try {
        final auth = context.read<AuthSession>();
        token = await auth.getValidAccessToken();
      } catch (_) {
        token = null;
      }
      final response = await _bookingApi.fetchCarOptions(bearerToken: token);
      if (!mounted) return;
      final mapped =
          response.carOptions
              .map(
                (option) => _CarTypeOption(
                  id: option.id,
                  title: option.title,
                  subtitle: option.subtitle,
                  seats: option.seats,
                  icon: _iconForCarOption(option.id),
                  pricePerKmGbp: option.pricePerKmGbp,
                ),
              )
              .toList(growable: false);
      setState(() {
        _carCurrencyCode = response.currencyCode;
        _carTypeOptions = mapped;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _carOptionsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _carOptionsError = 'Could not load car options right now. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _carOptionsLoading = false);
      }
    }
  }

  Future<_CarTypeOption?> _showCarTypePicker() async {
    if (_carOptionsLoading) {
      _showBottomMessage('Loading car options...');
      return null;
    }
    if (_carTypeOptions.isEmpty) {
      _showBottomMessage(
        _carOptionsError ?? 'No car options available right now. Try again.',
      );
      return null;
    }
    return showModalBottomSheet<_CarTypeOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              drivepalModalTopInset(ctx),
              12,
              drivepalModalBottomInset(ctx),
            ),
            child: DrivepalBookingSheet(
              title: 'Choose your car type',
              subtitle: 'Select your preferred seating and price per km.',
              maxHeight: _selectionSheetMaxHeight(ctx),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final option in _carTypeOptions) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                        onTap: () => Navigator.of(ctx).pop(option),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                            border: Border.all(
                              color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
                            ),
                            color: DrivepalTokens.bgCardTitleBar.withValues(alpha: 0.48),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: DrivepalTokens.bgPrimary.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    size: 21,
                                    color: DrivepalTokens.bgPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.title,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: DrivepalTokens.textHeading,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.subtitle,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: DrivepalTokens.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        () {
                                          final estimate = _estimateFareGbp(option);
                                          final perKm =
                                              '${_formatCurrency(option.pricePerKmGbp)}/km';
                                          if (estimate == null) {
                                            return perKm;
                                          }
                                          return '$perKm • Est ${_formatCurrency(estimate)}';
                                        }(),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: DrivepalTokens.textBody,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: DrivepalTokens.bgInput,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: DrivepalTokens.borderCard),
                                  ),
                                  child: Text(
                                    '${option.seats} seats',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: DrivepalTokens.textBody,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onReviewCtaPressed() async {
    if (_selectedCarType == null) {
      await _onRequestRidePressed();
      if (!mounted) return;
      await _ensureCarOptionsLoaded();
      if (!mounted) return;
      final selected = await _showCarTypePicker();
      if (!mounted || selected == null) return;
      setState(() => _selectedCarType = selected);
      return;
    }
    if (_selectedPaymentCard == null) {
      if (_paymentBusy) return;
      setState(() => _paymentBusy = true);
      final selected = await _pickPaymentCard();
      if (!mounted) return;
      setState(() => _paymentBusy = false);
      if (selected != null) {
        setState(() => _selectedPaymentCard = selected);
      }
      return;
    }

    await _finishBooking();
  }

  Future<void> _finishBooking({bool skipChargeConfirmation = false}) async {
    final car = _selectedCarType;
    final payment = _selectedPaymentCard;
    final pick = _pickLl;
    final drop = _dropLl;
    final pickupAddress = _pickupCtrl.text.trim();
    final dropoffAddress = _dropoffCtrl.text.trim();
    if (car == null || payment == null || pick == null || drop == null) {
      _showBottomMessage(
        'Complete pickup, destination, car and payment first.',
      );
      return;
    }
    if (pickupAddress.isEmpty || dropoffAddress.isEmpty) {
      _showBottomMessage('Pickup and destination are required.');
      return;
    }
    final estimatedFare = _estimateFareGbp(car);
    if (estimatedFare == null || estimatedFare <= 0) {
      _showBottomMessage(
        'Route fare is not ready yet. Please wait for route calculation.',
      );
      return;
    }
    if (!skipChargeConfirmation) {
      final confirmed = await _showChargeConfirmationModal(
        amountLabel: _formatCurrency(estimatedFare),
        paymentLabel: '${payment.brand.toUpperCase()} ${payment.maskedNumber}',
      );
      if (!mounted || !confirmed) {
        return;
      }
    }
    if (_advanceRequestRideBusy) return;

    setState(() => _advanceRequestRideBusy = true);
    _showPaymentProgressModal();
    var shouldRetry = false;
    try {
      final token = await context.read<AuthSession>().getValidAccessToken();
      if (!mounted) return;
      if (token == null) {
        _showBottomMessage('Please sign in again to finish booking.');
        return;
      }

      final route = _routeResult;
      final selectedMinutes = _selectedScheduleOption.minutesFromNow;
      final scheduledFor =
          selectedMinutes == null
              ? null
              : DateTime.now()
                  .add(Duration(minutes: selectedMinutes))
                  .toUtc()
                  .toIso8601String();
      await _bookingApi.createRideBooking({
        'pickup': {
          'address': pickupAddress,
          'latitude': pick.latitude,
          'longitude': pick.longitude,
        },
        'dropoff': {
          'address': dropoffAddress,
          'latitude': drop.latitude,
          'longitude': drop.longitude,
        },
        'route': {
          if (route?.distanceMeters != null)
            'distanceMeters': route!.distanceMeters,
          if (route?.durationSeconds != null)
            'durationSeconds': route!.durationSeconds,
          if (route?.durationInTrafficSeconds != null)
            'durationInTrafficSeconds': route!.durationInTrafficSeconds,
        },
        'car': {'id': car.id, 'title': car.title, 'seats': car.seats},
        'payment': {
          'id': payment.id,
          'brand': payment.brand,
          'maskedNumber': payment.maskedNumber,
        },
        if (scheduledFor != null) 'scheduledFor': scheduledFor,
      }, bearerToken: token);
      if (!mounted) return;
      _dismissPaymentProgressModal();
      _showBottomMessage('Ride request sent. We will notify you soon.');
      await _showFinishBookingDialog();
      if (!mounted) return;
      _resetBookingDraftAfterFinish();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _dismissPaymentProgressModal();
      shouldRetry = await _showPaymentFailureRetryModal(message: e.message);
    } catch (_) {
      if (!mounted) return;
      _dismissPaymentProgressModal();
      shouldRetry = await _showPaymentFailureRetryModal(
        message: 'Could not complete payment right now. Please try again.',
      );
    } finally {
      _dismissPaymentProgressModal();
      if (mounted) {
        setState(() => _advanceRequestRideBusy = false);
      }
    }
    if (shouldRetry && mounted) {
      await _finishBooking(skipChargeConfirmation: true);
    }
  }

  void _resetBookingDraftAfterFinish() {
    _pickDeb?.cancel();
    _dropDeb?.cancel();
    setState(() {
      _step = _BookWizardStep.pickup;
      _pickupCtrl.clear();
      _dropoffCtrl.clear();
      _pickLl = null;
      _dropLl = null;
      _routePts = <LatLng>[];
      _routeResult = null;
      _selectedCarType = null;
      _selectedPaymentCard = null;
      _selectedScheduleOption = _scheduleOptions.first;
      _pickupLookupMessage = null;
      _dropoffLookupMessage = null;
      _pickBusy = false;
      _dropBusy = false;
      _routeBusy = false;
      _pickupCurrentLocationBusy = false;
    });
  }

  void _showBottomMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _showFinishBookingDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
          ),
          backgroundColor: DrivepalTokens.bgCard,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DrivepalTokens.bgPrimary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.done_all_rounded,
                      size: 32,
                      color: DrivepalTokens.bgPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ride request sent',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DrivepalTokens.textHeading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your request will be picked up by an available driver. '
                  'We will notify you with driver and trip details shortly.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DrivepalTokens.textBody,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Got it'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showChargeConfirmationModal({
    required String amountLabel,
    required String paymentLabel,
  }) async {
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
                  const Expanded(child: Text('Confirm payment')),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You will be charged $amountLabel for this ride request.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: DrivepalTokens.textBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Card: $paymentLabel',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: DrivepalTokens.textMuted),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Confirm and pay'),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: DrivepalTokens.bgCard,
                      foregroundColor: DrivepalTokens.textDanger,
                      side: BorderSide(
                        color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
    return didConfirm;
  }

  void _showPaymentProgressModal() {
    if (_paymentProgressDialogVisible || !mounted) {
      return;
    }
    _paymentProgressDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: DrivepalTokens.bgCard,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
              side: BorderSide(
                color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
              ),
            ),
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payment in progress. Please wait...',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodyMedium?.copyWith(color: DrivepalTokens.textBody),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _paymentProgressDialogVisible = false;
    });
  }

  void _dismissPaymentProgressModal() {
    if (!_paymentProgressDialogVisible || !mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    _paymentProgressDialogVisible = false;
  }

  Future<bool> _showPaymentFailureRetryModal({required String message}) async {
    return (await showDialog<bool>(
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
              title: const Text('Payment failed'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Retry'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Future<PaymentMethodCard?> _pickPaymentCard() async {
    final auth = context.read<AuthSession>();
    final store = context.read<PaymentMethodsStore>();
    await store.loadCards(auth);
    if (!mounted) {
      return null;
    }
    while (mounted) {
      final result = await _showPaymentPicker(
        cards: store.cards,
        loading: store.isLoading,
        error: store.error,
      );
      if (!mounted || result == null) {
        return null;
      }
      if (result.card != null) {
        return result.card;
      }
      if (!result.requestAddCard) {
        return null;
      }
      try {
        await store.addCard(auth);
        if (kIsWeb) {
          _showBottomMessage('Redirecting to Stripe secure card setup...');
          return null;
        }
      } on StripeException catch (e) {
        if (!mounted) {
          return null;
        }
        if (e.error.code != FailureCode.Canceled) {
          _showBottomMessage(e.error.localizedMessage ?? 'Could not add card.');
        }
      } on AuthApiException catch (e) {
        if (!mounted) {
          return null;
        }
        _showBottomMessage(e.message);
      }
      if (!mounted) {
        return null;
      }
    }
    return null;
  }

  Future<_PaymentPickerResult?> _showPaymentPicker({
    required List<PaymentMethodCard> cards,
    required bool loading,
    required String? error,
  }) async {
    return showModalBottomSheet<_PaymentPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              drivepalModalTopInset(ctx),
              12,
              drivepalModalBottomInset(ctx),
            ),
            child: DrivepalBookingSheet(
              title: 'Choose payment method',
              subtitle: 'Select a saved card or add a new one.',
              maxHeight: _selectionSheetMaxHeight(ctx),
              body:
                  loading
                      ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : cards.isEmpty
                      ? Text(
                        error ?? 'No saved cards yet. Add one to continue.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: DrivepalTokens.textMuted),
                      )
                      : Column(
                        children:
                            cards
                                .map(
                                  (card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                                        onTap:
                                            () => Navigator.of(
                                              ctx,
                                            ).pop(_PaymentPickerResult(card: card)),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
                                            border: Border.all(
                                              color: DrivepalTokens.borderCard.withValues(
                                                alpha: 0.95,
                                              ),
                                            ),
                                            color: DrivepalTokens.bgCardTitleBar.withValues(
                                              alpha: 0.48,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              11,
                                              12,
                                              11,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 38,
                                                  height: 38,
                                                  decoration: BoxDecoration(
                                                    color: DrivepalTokens.bgPrimary.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
                                                  ),
                                                  child: const Icon(
                                                    Icons.credit_card_rounded,
                                                    size: 21,
                                                    color: DrivepalTokens.bgPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${card.brand.toUpperCase()} ${card.maskedNumber}',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: DrivepalTokens.textHeading,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Expires ${card.expMonth.toString().padLeft(2, '0')}/${card.expYear}',
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: DrivepalTokens.textMuted,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: DrivepalTokens.textMuted,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                      ),
              footer: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(
                    ctx,
                  ).pop(const _PaymentPickerResult(requestAddCard: true));
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a card with Stripe'),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onPickupNext() async {
    FocusScope.of(context).unfocus();
    final q = _pickupCtrl.text.trim();
    if (q.isEmpty || _advancePickupBusy) return;
    setState(() => _advancePickupBusy = true);
    try {
      final LatLng pick;
      if (_pickLl != null) {
        pick = _pickLl!;
      } else {
        final hit = await _maps.geocode(q);
        if (!mounted) return;
        if (hit == null) {
          _pickupLookupMessage =
              DrivepalAppShellCopy.riderBookLookupApproximatePin;
        }
        pick = hit?.latLng ?? BookingMapDefaults.approximateLatLngForQuery(q);
      }
      if (!mounted) return;
      setState(() {
        _pickLl = pick;
        _pickBusy = false;
        _routeResult = null;
        _step = _BookWizardStep.dropoff;
      });
      _scheduleFit();
      if (_dropLl != null) unawaited(_refreshRoute());
    } finally {
      if (mounted) {
        setState(() => _advancePickupBusy = false);
      }
    }
  }

  Future<void> _onUseCurrentPickupLocation() async {
    FocusScope.of(context).unfocus();
    if (_pickupCurrentLocationBusy) return;
    setState(() {
      _pickupCurrentLocationBusy = true;
      _pickBusy = false;
      _pickupLookupMessage = null;
    });
    try {
      final result = await _resolveCurrentPickupLocation();
      if (!mounted) return;
      final pickedLatLng = result.latLng;
      if (pickedLatLng == null) {
        setState(() {
          _pickupLookupMessage = result.feedback;
        });
        return;
      }
      final reverse = await _maps.reverseGeocode(pickedLatLng);
      if (!mounted) return;
      final pickupAddress =
          reverse?.formattedAddress.trim().isNotEmpty == true
              ? reverse!.formattedAddress.trim()
              : '${pickedLatLng.latitude.toStringAsFixed(5)}, '
                  '${pickedLatLng.longitude.toStringAsFixed(5)}';

      setState(() {
        _pickupCtrl.text = pickupAddress;
        _pickLl = pickedLatLng;
        _routePts = [];
        _routeResult = null;
        _pickupLookupMessage = null;
        _selectedCarType = null;
        _selectedPaymentCard = null;
      });

      if (_dropLl != null) {
        await _refreshRoute();
      } else {
        _scheduleFit();
      }
    } finally {
      if (mounted) {
        setState(() => _pickupCurrentLocationBusy = false);
      }
    }
  }

  Future<({LatLng? latLng, String? feedback})>
  _resolveCurrentPickupLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          latLng: null,
          feedback:
              DrivepalAppShellCopy.riderBookPickupCurrentLocationServiceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return (
          latLng: null,
          feedback:
              DrivepalAppShellCopy.riderBookPickupCurrentLocationPermissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return (
          latLng: null,
          feedback:
              DrivepalAppShellCopy.riderBookPickupCurrentLocationPermissionBlocked,
        );
      }

      if (await _hasReducedLocationAccuracy()) {
        return (
          latLng: null,
          feedback: DrivepalAppShellCopy.riderBookPickupCurrentLocationImprecise,
        );
      }

      final position = await _readMostAccurateCurrentPosition();
      if (position.accuracy > _currentPickupAcceptedAccuracyMeters) {
        return (
          latLng: null,
          feedback: DrivepalAppShellCopy.riderBookPickupCurrentLocationImprecise,
        );
      }
      return (
        latLng: LatLng(position.latitude, position.longitude),
        feedback: null,
      );
    } on MissingPluginException {
      return (
        latLng: null,
        feedback: DrivepalAppShellCopy.riderBookPickupCurrentLocationUnavailable,
      );
    } catch (_) {
      return (
        latLng: null,
        feedback: DrivepalAppShellCopy.riderBookPickupCurrentLocationFailed,
      );
    }
  }

  Future<bool> _hasReducedLocationAccuracy() async {
    try {
      var accuracy = await Geolocator.getLocationAccuracy();
      if (accuracy == LocationAccuracyStatus.reduced &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          accuracy = await Geolocator.requestTemporaryFullAccuracy(
            purposeKey: 'PickupLocation',
          );
        } catch (_) {}
      }
      return accuracy == LocationAccuracyStatus.reduced;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Position> _readMostAccurateCurrentPosition() async {
    Position? best;
    Object? lastError;
    final settings = _locationSettingsForCurrentPlatform();

    StreamSubscription<Position>? subscription;
    final completer = Completer<Position?>();
    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(best);
    });

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (pos) {
          if (best == null || pos.accuracy < best!.accuracy) {
            best = pos;
          }
          if (pos.accuracy <= _currentPickupAcceptedAccuracyMeters &&
              !completer.isCompleted) {
            completer.complete(pos);
          }
        },
        onError: (Object error) {
          lastError = error;
          if (!completer.isCompleted) completer.complete(best);
        },
      );
      final streamed = await completer.future;
      if (streamed != null) {
        return streamed;
      }
    } catch (error) {
      lastError = error;
    } finally {
      timer.cancel();
      await subscription?.cancel();
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: settings,
        );
        final currentBest = best;
        if (currentBest == null || pos.accuracy < currentBest.accuracy) {
          best = pos;
        }
        if ((best?.accuracy ?? double.infinity) <=
            _currentPickupAcceptedAccuracyMeters) {
          break;
        }
      } catch (error) {
        lastError = error;
      }
      if (attempt < 1) {
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
    }
    final resolved = best;
    if (resolved != null) return resolved;
    throw lastError ?? StateError('Current position unavailable');
  }

  LocationSettings _locationSettingsForCurrentPlatform() {
    const accuracy = LocationAccuracy.bestForNavigation;
    const timeLimit = Duration(seconds: 12);
    if (kIsWeb) {
      return WebSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        maximumAge: Duration.zero,
        timeLimit: timeLimit,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          timeLimit: timeLimit,
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          timeLimit: timeLimit,
        );
      default:
        return const LocationSettings(
          accuracy: accuracy,
          distanceFilter: 0,
          timeLimit: timeLimit,
        );
    }
  }

  Future<void> _onDropoffNext() async {
    FocusScope.of(context).unfocus();
    final q = _dropoffCtrl.text.trim();
    if (q.isEmpty || _advanceDropoffBusy) return;
    setState(() => _advanceDropoffBusy = true);
    try {
      final LatLng drop;
      if (_dropLl != null) {
        drop = _dropLl!;
      } else {
        final hit = await _maps.geocode(q);
        if (!mounted) return;
        if (hit == null) {
          _dropoffLookupMessage =
              DrivepalAppShellCopy.riderBookLookupApproximatePin;
        }
        drop = hit?.latLng ?? BookingMapDefaults.approximateLatLngForQuery(q);
      }
      if (!mounted) return;
      setState(() {
        _dropLl = drop;
        _dropBusy = false;
        _routeResult = null;
      });
      if (_pickLl != null && _dropLl != null) {
        await _refreshRoute();
      }
      if (!mounted) return;
      setState(() => _step = _BookWizardStep.review);
      _scheduleFit();
    } finally {
      if (mounted) {
        setState(() => _advanceDropoffBusy = false);
      }
    }
  }

  Future<void> _onRequestRidePressed() async {
    FocusScope.of(context).unfocus();
    final pq = _pickupCtrl.text.trim();
    final dq = _dropoffCtrl.text.trim();
    if (pq.isEmpty || dq.isEmpty || _advanceRequestRideBusy) return;
    setState(() => _advanceRequestRideBusy = true);
    try {
      final LatLng pick;
      if (_pickLl != null) {
        pick = _pickLl!;
      } else {
        final hit = await _maps.geocode(pq);
        if (!mounted) return;
        if (hit == null) {
          _pickupLookupMessage =
              DrivepalAppShellCopy.riderBookLookupApproximatePin;
        }
        pick = hit?.latLng ?? BookingMapDefaults.approximateLatLngForQuery(pq);
      }
      final LatLng drop;
      if (_dropLl != null) {
        drop = _dropLl!;
      } else {
        final hit = await _maps.geocode(dq);
        if (!mounted) return;
        if (hit == null) {
          _dropoffLookupMessage =
              DrivepalAppShellCopy.riderBookLookupApproximatePin;
        }
        drop = hit?.latLng ?? BookingMapDefaults.approximateLatLngForQuery(dq);
      }
      if (!mounted) return;
      setState(() {
        _pickLl = pick;
        _dropLl = drop;
        _pickBusy = false;
        _dropBusy = false;
        _routeResult = null;
      });
      await _refreshRoute();
      _scheduleFit();
    } finally {
      if (mounted) {
        setState(() => _advanceRequestRideBusy = false);
      }
    }
  }

  @override
  void dispose() {
    _pickDeb?.cancel();
    _dropDeb?.cancel();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  void _onMapCtl(GoogleMapController c) {
    _mapCtl = c;
    _scheduleFit();
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_fitCameraThenRetry());
      });
    });
  }

  /// Map platform view can lag one frame vs [markers]; geocode may finish before [onMapCreated].
  Future<void> _fitCameraThenRetry() async {
    await _fitCamera();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _fitCamera();
  }

  LatLngBounds _latLngBoundsWithPadding(List<LatLng> pts) {
    var minLat = pts.first.latitude;
    var maxLat = minLat;
    var minLng = pts.first.longitude;
    var maxLng = minLng;
    for (final p in pts.skip(1)) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    const minSpan = 0.004;
    if (maxLat - minLat < minSpan) {
      minLat -= minSpan / 2;
      maxLat += minSpan / 2;
    }
    if (maxLng - minLng < minSpan) {
      minLng -= minSpan / 2;
      maxLng += minSpan / 2;
    }
    const pad = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  Future<void> _fitCamera() async {
    final ctl = _mapCtl;
    if (ctl == null) return;

    List<LatLng> frame() {
      if (_routePts.length >= 2) return List.of(_routePts);
      final l = <LatLng>[];
      if (_pickLl != null) l.add(_pickLl!);
      if (_dropLl != null) l.add(_dropLl!);
      return l;
    }

    Future<void> apply(CameraUpdate u) async {
      try {
        await ctl.animateCamera(u);
      } catch (_) {
        try {
          await ctl.moveCamera(u);
        } catch (_) {}
      }
    }

    final list = frame();
    if (list.isEmpty) {
      await apply(
        CameraUpdate.newLatLngZoom(
          BookingMapDefaults.defaultCenter,
          BookingMapDefaults.defaultZoom,
        ),
      );
      return;
    }

    if (list.length == 1) {
      await apply(
        CameraUpdate.newLatLngZoom(
          list.single,
          BookingMapDefaults.singlePinZoom,
        ),
      );
      return;
    }

    final bounds = _latLngBoundsWithPadding(list);
    await apply(CameraUpdate.newLatLngBounds(bounds, 56));
  }

  Future<void> _refreshRoute() async {
    final a = _pickLl;
    final b = _dropLl;
    if (a == null || b == null) return;
    if (!mounted) return;
    setState(() => _routeBusy = true);
    final route = await _maps.directions(a, b);
    if (!mounted) return;
    setState(() {
      _routeResult = route;
      _routePts = route.points;
      _routeBusy = false;
    });
    _scheduleFit();
  }

  void _onPickupEdited(String _) {
    _pickDeb?.cancel();
    final q = _pickupCtrl.text.trim();
    setState(() {
      _pickLl = null;
      _routePts = [];
      _routeResult = null;
      _pickBusy = q.isNotEmpty;
      _pickupLookupMessage = null;
      _selectedCarType = null;
      _selectedPaymentCard = null;
    });
    if (q.isEmpty) {
      setState(() => _pickBusy = false);
      _scheduleFit();
      return;
    }

    final seq = ++_pickSeq;
    _pickDeb = Timer(BookingMapDefaults.geocodeIdleDebounce, () async {
      if (!mounted || seq != _pickSeq) return;
      final query = _pickupCtrl.text.trim();
      if (query.isEmpty) return;

      setState(() => _pickBusy = true);
      final hit = await _maps.geocode(query);
      if (!mounted || seq != _pickSeq) return;

      setState(() {
        _pickBusy = false;
        _pickLl = hit?.latLng;
        _routeResult = null;
        _pickupLookupMessage =
            hit == null
                ? DrivepalAppShellCopy.riderBookPickupLookupNotFound
                : null;
      });

      if (_dropLl != null) {
        await _refreshRoute();
      } else {
        _scheduleFit();
      }
    });
  }

  void _onDropEdited(String _) {
    _dropDeb?.cancel();
    final q = _dropoffCtrl.text.trim();
    setState(() {
      _dropLl = null;
      _routePts = [];
      _routeResult = null;
      _dropBusy = q.isNotEmpty;
      _routeBusy = q.isNotEmpty;
      _dropoffLookupMessage = null;
      _selectedCarType = null;
      _selectedPaymentCard = null;
    });
    if (q.isEmpty) {
      setState(() {
        _dropBusy = false;
        _routeBusy = false;
      });
      _scheduleFit();
      return;
    }

    final seq = ++_dropSeq;
    _dropDeb = Timer(BookingMapDefaults.geocodeIdleDebounce, () async {
      if (!mounted || seq != _dropSeq) return;
      final query = _dropoffCtrl.text.trim();
      if (query.isEmpty) return;

      setState(() {
        _dropBusy = true;
        _routeBusy = true;
      });
      final hit = await _maps.geocode(query);
      if (!mounted || seq != _dropSeq) return;
      setState(() {
        _dropLl = hit?.latLng;
        _dropBusy = false;
        _routeResult = null;
        _dropoffLookupMessage =
            hit == null
                ? DrivepalAppShellCopy.riderBookDropoffLookupNotFound
                : null;
      });

      if (_pickLl != null && _dropLl != null) {
        await _refreshRoute();
        if (!mounted || seq != _dropSeq) return;
      } else {
        setState(() => _routeBusy = false);
      }
      _scheduleFit();
    });
  }

  Set<Marker> _markers() {
    return {
      if (_pickLl != null)
        gmaps_pi.AdvancedMarker(
          markerId: const MarkerId('pick'),
          position: _pickLl!,
          zIndex: 1,
          consumeTapEvents: true,
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: DrivepalAppShellCopy.riderBookSummaryPickupChip,
          ),
        ),
      if (_dropLl != null)
        gmaps_pi.AdvancedMarker(
          markerId: const MarkerId('drop'),
          position: _dropLl!,
          zIndex: 2,
          consumeTapEvents: true,
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: DrivepalAppShellCopy.riderBookSummaryDropoffChip,
          ),
        ),
    };
  }

  Set<Polyline> _polylines() {
    return {
      if (_routePts.length >= 2)
        Polyline(
          polylineId: const PolylineId('trip'),
          color: DrivepalTokens.bgPrimary,
          width: 5,
          points: _routePts,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: BookingInteractiveMap(
              markers: _markers(),
              polylines: _polylines(),
              initialCameraPosition: BookingMapDefaults.initialCamera,
              interactive: false,
              onControllerReady: _onMapCtl,
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: drivepalFloatingShellBodyPadding(
                  context,
                  extraBottom: 24,
                ),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      switch (_step) {
                        _BookWizardStep.pickup => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BookingWizardLocationField(
                              controller: _pickupCtrl,
                              semanticsLabel:
                                  DrivepalAppShellCopy.riderBookPickupSemantic,
                              hintText: DrivepalAppShellCopy.riderBookPickupHint,
                              autofocus: true,
                              emphasized: true,
                              isBusy: _pickBusy,
                              onChanged: _onPickupEdited,
                            ),
                            const SizedBox(height: 10),
                            BookingWizardCurrentLocationAction(
                              label:
                                  DrivepalAppShellCopy
                                      .riderBookPickupCurrentLocationLabel,
                              subtitle:
                                  DrivepalAppShellCopy
                                      .riderBookPickupCurrentLocationSubtitle,
                              isBusy: _pickupCurrentLocationBusy,
                              onTap: () {
                                unawaited(_onUseCurrentPickupLocation());
                              },
                            ),
                            if (_pickupLookupMessage != null) ...[
                              const SizedBox(height: 10),
                              BookingWizardLookupMessage(
                                text: _pickupLookupMessage!,
                              ),
                            ],
                            const SizedBox(height: 14),
                            BookingWizardTrailingNext(
                              label: DrivepalAppShellCopy.riderBookNextButtonLabel,
                              semanticsLabel:
                                  DrivepalAppShellCopy
                                      .riderBookNextSemanticsPickup,
                              hintDisabled:
                                  DrivepalAppShellCopy.riderBookNextHintDisabled,
                              enabled: _canNextPickup,
                              onPressed: () {
                                unawaited(_onPickupNext());
                              },
                            ),
                          ],
                        ),
                        _BookWizardStep.dropoff => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_pickupCtrl.text.trim().isNotEmpty) ...[
                              BookingRouteSummaryBanner(
                                pickupText: _pickupCtrl.text.trim(),
                                dropoffText:
                                    _dropoffCtrl.text.trim().isEmpty
                                        ? DrivepalAppShellCopy
                                            .riderBookDestinationHint
                                        : _dropoffCtrl.text.trim(),
                                onEditPickup: () {
                                  setState(
                                    () => _step = _BookWizardStep.pickup,
                                  );
                                },
                                onEditDropoff: () {},
                              ),
                              const SizedBox(height: 12),
                            ],
                            BookingWizardLocationField(
                              controller: _dropoffCtrl,
                              semanticsLabel:
                                  DrivepalAppShellCopy
                                      .riderBookDestinationSemantic,
                              hintText:
                                  DrivepalAppShellCopy.riderBookDestinationHint,
                              autofocus: true,
                              isBusy: _dropBusy || _routeBusy,
                              onChanged: _onDropEdited,
                            ),
                            if (_dropoffLookupMessage != null) ...[
                              const SizedBox(height: 10),
                              BookingWizardLookupMessage(
                                text: _dropoffLookupMessage!,
                              ),
                            ],
                            const SizedBox(height: 14),
                            BookingWizardTrailingNext(
                              label: DrivepalAppShellCopy.riderBookNextButtonLabel,
                              semanticsLabel:
                                  DrivepalAppShellCopy
                                      .riderBookNextSemanticsDropoff,
                              hintDisabled:
                                  DrivepalAppShellCopy.riderBookNextHintDisabled,
                              enabled: _canNextDropoff,
                              onPressed: () {
                                unawaited(_onDropoffNext());
                              },
                            ),
                          ],
                        ),
                        _BookWizardStep.review => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BookingRouteSummaryBanner(
                              pickupText:
                                  _pickupCtrl.text.trim().isEmpty
                                      ? '—'
                                      : _pickupCtrl.text.trim(),
                              dropoffText:
                                  _dropoffCtrl.text.trim().isEmpty
                                      ? '—'
                                      : _dropoffCtrl.text.trim(),
                              onEditPickup: () {
                                setState(() => _step = _BookWizardStep.pickup);
                              },
                              onEditDropoff: () {
                                setState(() => _step = _BookWizardStep.dropoff);
                              },
                              routePrimary: _routePrimarySummary,
                              routeSecondary: _routeSecondarySummary,
                              routeTertiary: _selectedCarSummary,
                              routeQuaternary: _selectedPaymentSummary,
                              onEditTertiary: () {
                                unawaited(_onEditSelectedCar());
                              },
                              onEditQuaternary: () {
                                unawaited(_onEditSelectedPaymentCard());
                              },
                            ),
                            const SizedBox(height: 10),
                            BookingSelectionInfoCard(
                              title: 'Schedule',
                              value: _selectedScheduleSummary,
                              icon: Icons.schedule_rounded,
                              onTap: () {
                                unawaited(_onEditSchedule());
                              },
                            ),
                            const SizedBox(height: 22),
                            BookingWizardTrailingNext(
                              label: _reviewCtaLabel,
                              semanticsLabel: _reviewCtaSemantics,
                              hintDisabled:
                                  DrivepalAppShellCopy.riderBookNextHintDisabled,
                              enabled: _canRequestRide,
                              isDarkStyle: true,
                              trailingIcon: _reviewCtaIcon,
                              onPressed: () {
                                unawaited(_onReviewCtaPressed());
                              },
                            ),
                          ],
                        ),
                      },
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
