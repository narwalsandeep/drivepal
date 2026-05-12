import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';

enum DrivepalLocationRole { pickup, dropoff, current }

class DrivepalLocationIcon extends StatelessWidget {
  const DrivepalLocationIcon({
    super.key,
    required this.icon,
    required this.role,
    this.size = 18,
    this.withSoftCircle = false,
  });

  final IconData icon;
  final DrivepalLocationRole role;
  final double size;
  final bool withSoftCircle;

  Color _iconColor() {
    switch (role) {
      case DrivepalLocationRole.pickup:
        return DrivepalTokens.locationPickup;
      case DrivepalLocationRole.dropoff:
        return DrivepalTokens.locationDropoff;
      case DrivepalLocationRole.current:
        return DrivepalTokens.locationCurrent;
    }
  }

  Color _softBg() {
    switch (role) {
      case DrivepalLocationRole.pickup:
        return DrivepalTokens.locationPickupSoftBg;
      case DrivepalLocationRole.dropoff:
      case DrivepalLocationRole.current:
        return DrivepalTokens.locationGreenSoftBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: size, color: _iconColor());
    if (!withSoftCircle) {
      return child;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _softBg()),
      child: Center(child: child),
    );
  }
}
