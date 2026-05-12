import 'package:flutter/material.dart';

import '../../theme/drivepal_tokens.dart';

/// Reusable themed booking modal sheet with consistent chrome and spacing.
class DrivepalBookingSheet extends StatelessWidget {
  const DrivepalBookingSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.maxHeight,
    required this.body,
    this.footer,
  });

  final String title;
  final String subtitle;
  final double maxHeight;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrivepalTokens.bgCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DrivepalTokens.radiusCard),
          bottom: Radius.circular(DrivepalTokens.radiusCard),
        ),
        border: Border.all(color: DrivepalTokens.borderCard.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 12),
            blurRadius: 28,
            color: DrivepalTokens.textHeading.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DrivepalTokens.borderCard,
                    borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: DrivepalTokens.textHeading,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: DrivepalTokens.textMuted),
              ),
              const SizedBox(height: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(child: body),
              ),
              if (footer != null) ...[
                const SizedBox(height: 10),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
