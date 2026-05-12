import 'package:flutter/material.dart';

import '../../services/notifications_api.dart';
import '../../theme/drivepal_tokens.dart';
import '../drivepal_tab_page_chrome.dart';

class DrivepalAlertCard extends StatelessWidget {
  const DrivepalAlertCard({
    super.key,
    required this.item,
    required this.timeLabel,
    required this.onTap,
  });

  final RiderNotificationItem item;
  final String timeLabel;
  final VoidCallback onTap;

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'trip_requested':
        return Icons.local_taxi_rounded;
      case 'trip_cancelled':
        return Icons.cancel_rounded;
      case 'payment':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
        onTap: onTap,
        child: DrivepalElevatedPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
                  color: DrivepalTokens.bgPrimary.withValues(alpha: 0.10),
                  border: Border.all(
                    color:
                        item.isRead
                            ? DrivepalTokens.borderCard.withValues(alpha: 0.65)
                            : DrivepalTokens.bgPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  _iconForKind(item.kind),
                  color: DrivepalTokens.accentLink,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              color: DrivepalTokens.textHeading,
                              fontWeight:
                                  item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: DrivepalTokens.bgPrimary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            item.isRead
                                ? DrivepalTokens.textMuted
                                : DrivepalTokens.textBody,
                        height: 1.34,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
