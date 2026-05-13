import 'package:flutter/material.dart';

import 'drivepal_tokens.dart';

class DrivepalBookingStatusVisual {
  const DrivepalBookingStatusVisual({
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
    required this.riderLabel,
    required this.riderDriverLineLabel,
    required this.driverLabel,
  });

  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final String riderLabel;
  final String riderDriverLineLabel;
  final String driverLabel;
}

abstract final class DrivepalBookingStatusTheme {
  static const DrivepalBookingStatusVisual requested = DrivepalBookingStatusVisual(
    icon: Icons.schedule_rounded,
    accentColor: DrivepalTokens.statusRequested,
    surfaceColor: DrivepalTokens.statusRequestedSoftBg,
    riderLabel: 'Waiting for driver',
    riderDriverLineLabel: 'No driver yet',
    driverLabel: 'Requested',
  );

  static const DrivepalBookingStatusVisual accepted = DrivepalBookingStatusVisual(
    icon: Icons.local_taxi_rounded,
    accentColor: DrivepalTokens.statusAccepted,
    surfaceColor: DrivepalTokens.statusAcceptedSoftBg,
    riderLabel: 'Driver accepted',
    riderDriverLineLabel: 'Driver assigned',
    driverLabel: 'Accepted',
  );

  static const DrivepalBookingStatusVisual arriving = DrivepalBookingStatusVisual(
    icon: Icons.local_taxi_rounded,
    accentColor: DrivepalTokens.statusArriving,
    surfaceColor: DrivepalTokens.statusArrivingSoftBg,
    riderLabel: 'Driver arriving',
    riderDriverLineLabel: 'Driver arriving',
    driverLabel: 'Driver arriving',
  );

  static const DrivepalBookingStatusVisual inProgress = DrivepalBookingStatusVisual(
    icon: Icons.route_rounded,
    accentColor: DrivepalTokens.statusInProgress,
    surfaceColor: DrivepalTokens.statusInProgressSoftBg,
    riderLabel: 'Ride in progress',
    riderDriverLineLabel: 'With driver',
    driverLabel: 'In progress',
  );

  static const DrivepalBookingStatusVisual completed = DrivepalBookingStatusVisual(
    icon: Icons.check_circle_rounded,
    accentColor: DrivepalTokens.statusCompleted,
    surfaceColor: DrivepalTokens.statusCompletedSoftBg,
    riderLabel: 'Completed',
    riderDriverLineLabel: 'Trip finished',
    driverLabel: 'Completed',
  );

  static const DrivepalBookingStatusVisual cancelled = DrivepalBookingStatusVisual(
    icon: Icons.cancel_rounded,
    accentColor: DrivepalTokens.textDanger,
    surfaceColor: DrivepalTokens.dangerSoftBg,
    riderLabel: 'Cancelled',
    riderDriverLineLabel: 'Trip cancelled',
    driverLabel: 'Cancelled',
  );

  static DrivepalBookingStatusVisual fromStatus(String status) {
    switch (status) {
      case 'requested':
        return requested;
      case 'accepted':
        return accepted;
      case 'driver_arriving':
        return arriving;
      case 'in_progress':
        return inProgress;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      default:
        return requested;
    }
  }
}
