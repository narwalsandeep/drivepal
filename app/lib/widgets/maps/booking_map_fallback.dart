import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';

/// Shown when [GoogleMap] is not available (unsupported platform / missing key).
class BookingMapFallback extends StatelessWidget {
  const BookingMapFallback({super.key, this.caption});

  /// Extra line for desktop runners (Linux / Windows / macOS).
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DrivepalTokens.borderCard,
            DrivepalTokens.bgScaffold,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 56,
                color: DrivepalTokens.accentIcon.withValues(alpha: 0.5),
              ),
              if (caption != null) ...[
                const SizedBox(height: 14),
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        height: 1.35,
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
