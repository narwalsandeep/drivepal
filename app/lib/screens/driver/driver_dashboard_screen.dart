import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're offline",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                      foregroundColor: scheme.onPrimary,
                    ),
                    onPressed: () {},
                    child: const Text('Go online'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Earnings and trip requests will show here.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: DrivepalTokens.textMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
