import 'package:flutter/material.dart';

import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_tokens.dart';

/// Layout math for route rail vs two stacked [_RouteTextField]s (avoids [IntrinsicHeight]
/// + [LayoutBuilder] conflicts in scroll views).
abstract final class _BookingRoutePanelLayout {
  static const double markerD = 13;
  static const double markerPadTop = 12;
  static const double markerPadBottom = 12;
  static const double trailPadV = 8;

  /// Single-line field block height (contentPadding + one line of body text).
  static const double fieldApproxHeight = 52;
  static const double fieldGap = 14;

  /// Height of the dotted connector between pickup and destination markers.
  static double dottedTrailHeight() {
    final stack = fieldApproxHeight * 2 + fieldGap;
    final overhead =
        markerPadTop + markerPadBottom + 2 * markerD + 2 * trailPadV;
    return (stack - overhead).clamp(40.0, 200.0);
  }
}

/// Neutral pickup marker vs brand destination marker.
abstract final class _RouteMarkerColors {
  static const pickup = DrivepalTokens.locationPickup;
  static const destination = DrivepalTokens.locationDropoff;
}

/// Pickup / drop-off: gray + brand anchors and an animated dotted path between them.
class DrivepalBookingRoutePanel extends StatelessWidget {
  const DrivepalBookingRoutePanel({
    super.key,
    required this.pickupController,
    required this.dropoffController,
    required this.onFieldChanged,
  });

  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final VoidCallback onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
        color: DrivepalTokens.bgCard,
        border: Border.all(
          color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 36,
            spreadRadius: -8,
            color: DrivepalTokens.textHeading.withValues(alpha: 0.11),
          ),
          BoxShadow(
            offset: const Offset(0, 6),
            blurRadius: 20,
            spreadRadius: 0,
            color: Colors.black.withValues(alpha: 0.055),
          ),
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 10,
            color: DrivepalTokens.bgPrimary.withValues(alpha: 0.09),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PickupDestinationRail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RouteTextField(
                    controller: pickupController,
                    semanticLabel: DrivepalAppShellCopy.riderBookPickupSemantic,
                    hintText: DrivepalAppShellCopy.riderBookPickupHint,
                    focusAccent: DrivepalTokens.accentLink,
                    onChanged: onFieldChanged,
                  ),
                  const SizedBox(height: 14),
                  _RouteTextField(
                    controller: dropoffController,
                    semanticLabel:
                        DrivepalAppShellCopy.riderBookDestinationSemantic,
                    hintText: DrivepalAppShellCopy.riderBookDestinationHint,
                    focusAccent: DrivepalTokens.accentLink,
                    onChanged: onFieldChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Left rail: muted circle → dotted animation → brand circle (aligned with fields).
class _PickupDestinationRail extends StatelessWidget {
  const _PickupDestinationRail();

  @override
  Widget build(BuildContext context) {
    final d = _BookingRoutePanelLayout.markerD;
    final trailH = _BookingRoutePanelLayout.dottedTrailHeight();

    return SizedBox(
      width: d,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: _BookingRoutePanelLayout.markerPadTop,
            ),
            child: _FilledMarker(
              color: _RouteMarkerColors.pickup,
              size: d,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _BookingRoutePanelLayout.trailPadV,
            ),
            child: SizedBox(
              width: d,
              height: trailH,
              child: const _AnimatedDottedTrail(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: _BookingRoutePanelLayout.markerPadBottom,
            ),
            child: _FilledMarker(
              color: _RouteMarkerColors.destination,
              size: d,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledMarker extends StatelessWidget {
  const _FilledMarker({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: color.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

/// Animated vertical dots shading from muted gray toward brand color (top → bottom).
class _AnimatedDottedTrail extends StatefulWidget {
  const _AnimatedDottedTrail();

  @override
  State<_AnimatedDottedTrail> createState() => _AnimatedDottedTrailState();
}

class _AnimatedDottedTrailState extends State<_AnimatedDottedTrail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _dotDiameter = 4.5;
  static const _spacing = 5.0;

  /// Mid-tone connector gray (between anchors).
  static const _trailGray = DrivepalTokens.textFaint;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    }
    if (!reduceMotion &&
        !_controller.isAnimating &&
        _controller.value == 0) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return _StaticDots();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxHeight;
        final step = _dotDiameter + _spacing;
        final count = usable > step ? (usable / step).floor().clamp(2, 32) : 2;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < count; i++)
                  _TrailDot(color: _dotColor(i, count, t)),
              ],
            );
          },
        );
      },
    );
  }

  Color _dotColor(int index, int count, double t) {
    final green = _RouteMarkerColors.destination;
    // Travelling brightness front; dots behind fade back toward muted gray.
    final phase = (t * (count + 2)).clamp(0.0, count + 2.001);
    final peak = phase - index;
    var bright = (1 - (peak.abs() / 2.35)).clamp(0.0, 1.0);
    if (bright < 0.12) bright = index / (count * 6 + 6);
    bright = Curves.easeOut.transform(bright.clamp(0.0, 1.0));
    return Color.lerp(_trailGray, green, bright)!;
  }
}

/// Non-animated dashed look when Reduce Motion / disable animations is on.
class _StaticDots extends StatelessWidget {
  static const double _dia = _AnimatedDottedTrailState._dotDiameter;
  static const double _gap = _AnimatedDottedTrailState._spacing;
  static final Color _muted = Color.lerp(
    DrivepalTokens.textFaint,
    DrivepalTokens.bgPrimary,
    0.35,
  )!;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.maxHeight;
        final step = _dia + _gap;
        final count =
            usable > step ? (usable / step).floor().clamp(3, 32) : 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var k = 0; k < count; k++)
              _TrailDot(color: _muted, diameter: _dia),
          ],
        );
      },
    );
  }
}

class _TrailDot extends StatelessWidget {
  const _TrailDot({required this.color, this.diameter = _AnimatedDottedTrailState._dotDiameter});

  final Color color;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _RouteTextField extends StatelessWidget {
  const _RouteTextField({
    required this.controller,
    required this.semanticLabel,
    required this.hintText,
    required this.focusAccent,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String hintText;
  final Color focusAccent;
  final VoidCallback onChanged;

  OutlineInputBorder _outlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final idle = DrivepalTokens.borderInput.withValues(alpha: 0.75);

    return Semantics(
      label: semanticLabel,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.streetAddress,
        textCapitalization: TextCapitalization.words,
        autocorrect: false,
        style: textTheme.bodyLarge?.copyWith(
          color: DrivepalTokens.textInput,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: textTheme.bodyLarge?.copyWith(
            color: DrivepalTokens.textFaint,
            fontWeight: FontWeight.w400,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border:
              _outlineBorder(DrivepalTokens.borderCard.withValues(alpha: 0.4)),
          enabledBorder: _outlineBorder(idle),
          disabledBorder:
              _outlineBorder(DrivepalTokens.borderCard.withValues(alpha: 0.35)),
          focusedBorder: _outlineBorder(focusAccent, width: 1.5),
          errorBorder: _outlineBorder(Theme.of(context).colorScheme.error),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.error,
              width: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
