import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_circular_primary_shadow.dart';
import '../../theme/drivepal_shell_typography.dart';
import '../../theme/drivepal_tokens.dart';
import '../common/drivepal_location_icon.dart';

/// Prominent single-location field for pickup / drop-off wizard steps.
///
/// Symmetric inset, focus ring on the card edge (no asymmetric inner borders).
class BookingWizardLocationField extends StatefulWidget {
  const BookingWizardLocationField({
    super.key,
    required this.controller,
    required this.semanticsLabel,
    required this.hintText,
    required this.onChanged,
    this.autofocus = false,
    this.isBusy = false,
    this.emphasized = false,
  });

  final TextEditingController controller;
  final String semanticsLabel;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final bool isBusy;
  final bool emphasized;

  @override
  State<BookingWizardLocationField> createState() =>
      _BookingWizardLocationFieldState();
}

class _BookingWizardLocationFieldState
    extends State<BookingWizardLocationField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  bool get _focused => _focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    const inset = 20.0;

    // Large, calm address copy — darker for stronger readability while typing.
    final addressStyle = GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.54,
      letterSpacing: 0.1,
      color: DrivepalTokens.textHeading,
    );
    final hintStyle = GoogleFonts.inter(
      fontSize: 19,
      fontWeight: FontWeight.w400,
      height: 1.54,
      letterSpacing: 0.08,
      color: DrivepalTokens.textFaint,
    );

    final activeVisual = _focused || widget.emphasized;
    final borderColor =
        activeVisual
            ? DrivepalTokens.bgPrimary.withValues(alpha: 0.92)
            : DrivepalTokens.borderCard.withValues(alpha: 0.92);
    final borderWidth = activeVisual ? 1.6 : 1.0;

    return Semantics(
      label: widget.semanticsLabel,
      textField: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
          color: DrivepalTokens.bgCard,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 32,
              spreadRadius: -8,
              color: DrivepalTokens.textHeading.withValues(
                alpha: activeVisual ? 0.13 : 0.05,
              ),
            ),
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 12,
              color: DrivepalTokens.bgPrimary.withValues(
                alpha: activeVisual ? 0.2 : 0.07,
              ),
            ),
            if (widget.emphasized)
              BoxShadow(
                offset: const Offset(0, 16),
                blurRadius: 36,
                spreadRadius: -12,
                color: Colors.black.withValues(alpha: 0.18),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: inset,
            vertical: inset,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  minLines: 2,
                  maxLines: 5,
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  style: addressStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    hintStyle: hintStyle,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (widget.isBusy) ...[
                SizedBox(
                  width: inset,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: DrivepalTokens.bgPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline lookup feedback under pickup/drop-off fields.
class BookingWizardLookupMessage extends StatelessWidget {
  const BookingWizardLookupMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        color: DrivepalTokens.bgCardTitleBar,
        border: Border.all(color: DrivepalTokens.borderCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: DrivepalTokens.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: tt.bodySmall?.copyWith(
                  color: DrivepalTokens.textBody,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium quick action to auto-fill pickup with device location.
class BookingWizardCurrentLocationAction extends StatelessWidget {
  const BookingWizardCurrentLocationAction({
    super.key,
    required this.label,
    required this.subtitle,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
        onTap: isBusy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
            color: DrivepalTokens.bgCard,
            border: Border.all(
              color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 8),
                blurRadius: 22,
                spreadRadius: -10,
                color: DrivepalTokens.textHeading.withValues(alpha: 0.1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DrivepalTokens.locationGreenSoftBg,
                  ),
                  child: const DrivepalLocationIcon(
                    icon: Icons.my_location_rounded,
                    role: DrivepalLocationRole.current,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: tt.titleSmall?.copyWith(
                          color: DrivepalTokens.locationPickup,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isBusy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: DrivepalTokens.bgPrimary,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: DrivepalTokens.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable pickup + drop-off rows for review / quick edit.
class BookingRouteSummaryBanner extends StatelessWidget {
  const BookingRouteSummaryBanner({
    super.key,
    required this.pickupText,
    required this.dropoffText,
    required this.onEditPickup,
    required this.onEditDropoff,
    this.routePrimary,
    this.routeSecondary,
    this.routeTertiary,
    this.routeQuaternary,
    this.onEditTertiary,
    this.onEditQuaternary,
  });

  final String pickupText;
  final String dropoffText;
  final VoidCallback onEditPickup;
  final VoidCallback onEditDropoff;
  final String? routePrimary;
  final String? routeSecondary;
  final String? routeTertiary;
  final String? routeQuaternary;
  final VoidCallback? onEditTertiary;
  final VoidCallback? onEditQuaternary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: DrivepalAppShellCopy.riderBookEditLocationHint,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
          color: DrivepalTokens.bgCard,
          border: Border.all(
            color: DrivepalTokens.borderCard.withValues(alpha: 0.92),
          ),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 10),
              blurRadius: 28,
              color: DrivepalTokens.textHeading.withValues(alpha: 0.07),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryRouteRow(
              pickupText: pickupText,
              dropoffText: dropoffText,
              onEditPickup: onEditPickup,
              onEditDropoff: onEditDropoff,
            ),
            if (routeTertiary != null || routeQuaternary != null) ...[
              _SummarySeparator(),
              if (routeTertiary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                  child: _InlineSelectionBox(
                    icon: Icons.directions_car_filled_rounded,
                    value: routeTertiary!,
                    onTap: onEditTertiary,
                  ),
                ),
              if (routeTertiary != null && routeQuaternary != null)
                const _SummarySeparator(),
              if (routeQuaternary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: _InlineSelectionBox(
                    icon: Icons.credit_card_rounded,
                    value: routeQuaternary!,
                    onTap: onEditQuaternary,
                  ),
                ),
            ],
            if (routePrimary != null || routeSecondary != null) ...[
              _SummarySeparator(),
              _RouteFactsRow(primary: routePrimary, secondary: routeSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRouteRow extends StatelessWidget {
  const _SummaryRouteRow({
    required this.pickupText,
    required this.dropoffText,
    required this.onEditPickup,
    required this.onEditDropoff,
  });

  final String pickupText;
  final String dropoffText;
  final VoidCallback onEditPickup;
  final VoidCallback onEditDropoff;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final routeTextStyle = DrivepalShellTypography.elevatedInlineTitle(
      tt,
    ).copyWith(fontSize: 15.5, fontWeight: FontWeight.w500, height: 1.3);
    final actionStyle = DrivepalShellTypography.elevatedInlineBody(
      tt,
    ).copyWith(color: DrivepalTokens.textBody, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('booking-review-edit-pickup'),
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
            onTap: onEditPickup,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  const DrivepalLocationIcon(
                    icon: Icons.radio_button_checked_rounded,
                    role: DrivepalLocationRole.pickup,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickupText,
                      textAlign: TextAlign.left,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: routeTextStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: _SummaryTrailingAction(style: actionStyle),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: DrivepalTokens.textMuted,
              ),
            ),
          ),
          InkWell(
            key: const ValueKey('booking-review-edit-dropoff'),
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
            onTap: onEditDropoff,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  const DrivepalLocationIcon(
                    icon: Icons.location_on_rounded,
                    role: DrivepalLocationRole.dropoff,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dropoffText,
                      textAlign: TextAlign.left,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: routeTextStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: _SummaryTrailingAction(style: actionStyle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteFactsRow extends StatelessWidget {
  const _RouteFactsRow({this.primary, this.secondary});

  final String? primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (primary != null)
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 17,
                  color: DrivepalTokens.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    primary!,
                    style: GoogleFonts.inter(
                      color: DrivepalTokens.textHeading,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
              ],
            ),
          if (secondary != null) ...[
            const SizedBox(height: 6),
            Text(
              secondary!,
              style: tt.bodyMedium?.copyWith(
                color: DrivepalTokens.textBody,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineSelectionBox extends StatelessWidget {
  const _InlineSelectionBox({
    required this.icon,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 12),
          child: Row(
            children: [
              Icon(icon, size: 19, color: DrivepalTokens.textHeading),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    color: DrivepalTokens.textHeading,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 86,
                child: _SummaryTrailingAction(
                  style: DrivepalShellTypography.elevatedInlineBody(tt).copyWith(
                    color: DrivepalTokens.textBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySeparator extends StatelessWidget {
  const _SummarySeparator();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: DrivepalTokens.borderCard.withValues(alpha: 0.85),
    );
  }
}

class _SummaryTrailingAction extends StatelessWidget {
  const _SummaryTrailingAction({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DrivepalAppShellCopy.riderBookEditLocationHint, style: style),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: DrivepalTokens.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class BookingSelectionInfoCard extends StatelessWidget {
  const BookingSelectionInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
            color: DrivepalTokens.bgCardTitleBar,
            border: Border.all(color: DrivepalTokens.borderCard),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DrivepalTokens.bgPrimary.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 17, color: DrivepalTokens.bgPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.bodySmall?.copyWith(
                          color: DrivepalTokens.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: tt.bodyMedium?.copyWith(
                          color: DrivepalTokens.textHeading,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DrivepalAppShellCopy.riderBookEditLocationHint,
                        style: DrivepalShellTypography.elevatedInlineBody(tt),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: DrivepalTokens.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Right-aligned compact CTA ([Next] / Request ride): shadow pill + trailing arrow.
class BookingWizardTrailingNext extends StatelessWidget {
  const BookingWizardTrailingNext({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.enabled,
    required this.onPressed,
    this.hintDisabled,
    this.isDarkStyle = false,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  final String label;
  final String semanticsLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final String? hintDisabled;
  final bool isDarkStyle;
  final IconData trailingIcon;

  static const double _pillRadius = DrivepalTokens.radiusButton;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? DrivepalTokens.textOnPrimary : DrivepalTokens.textMuted;
    final labelStyle = DrivepalShellTypography.goButtonLabel.copyWith(
      color: fg,
      letterSpacing: 0.15,
      fontSize: 15,
    );

    final iconColor = fg;

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 10),
          Icon(trailingIcon, size: 22, color: iconColor),
        ],
      ),
    );

    /// Brand monochrome by default; review CTA can opt into darker gray emphasis.
    final fill =
        enabled
            ? (isDarkStyle ? DrivepalTokens.bgPrimaryHover : DrivepalTokens.bgPrimary)
            : Color.lerp(DrivepalTokens.bgScaffold, DrivepalTokens.bgPrimary, 0.14)!;

    final pill = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_pillRadius),
        boxShadow:
            enabled
                ? DrivepalCircularPrimaryShadow.layered
                : DrivepalCircularPrimaryShadow.subdued,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(_pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_pillRadius),
          onTap: enabled ? onPressed : null,
          splashColor: DrivepalTokens.textOnPrimary.withValues(alpha: 0.22),
          highlightColor: DrivepalTokens.textOnPrimary.withValues(alpha: 0.09),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_pillRadius),
              color: fill,
              border:
                  enabled
                      ? null
                      : Border.all(
                        color: DrivepalTokens.borderCard.withValues(alpha: 0.88),
                        width: 1.25,
                      ),
            ),
            child: row,
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticsLabel,
        hint: enabled ? null : hintDisabled,
        child: pill,
      ),
    );
  }
}
