import 'package:flutter/material.dart';

import '../theme/drivepal_shell_typography.dart';
import '../theme/drivepal_tokens.dart';

export 'profile/drivepal_profile_chrome.dart' show DrivepalProfileSectionLabel;

/// Top-of-page hero: icon, title, subtitle — matches profile card language.
class DrivepalFeatureIntroCard extends StatelessWidget {
  const DrivepalFeatureIntroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DrivepalTokens.bgCard,
            DrivepalTokens.bgCardTitleBar.withValues(alpha: 0.55),
            DrivepalTokens.bgScaffold,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: DrivepalTokens.borderCard.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -4,
            color: DrivepalTokens.textHeading.withValues(alpha: 0.08),
          ),
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8,
            color: DrivepalTokens.bgPrimary.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: DrivepalShellTypography.introIconDecoration(),
              child: Icon(icon, color: DrivepalTokens.accentLink, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeLabel != null && badgeLabel!.isNotEmpty) ...[
                    Text(
                      badgeLabel!.toUpperCase(),
                      style: DrivepalShellTypography.featureIntroBadge(textTheme),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    title,
                    style: DrivepalShellTypography.featureIntroTitle(textTheme),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: DrivepalShellTypography.featureIntroSubtitle(textTheme),
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

/// White panel with hairline border + soft lift (settings-tile family).
class DrivepalElevatedPanel extends StatelessWidget {
  const DrivepalElevatedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
        color: DrivepalTokens.bgCard,
        border: Border.all(
          color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 14,
            spreadRadius: 0,
            color: DrivepalTokens.textHeading.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Icon rail + title/body summary inside [DrivepalElevatedPanel] (wallet empty state, etc.).
class DrivepalPanelIconSummary extends StatelessWidget {
  const DrivepalPanelIconSummary({
    super.key,
    required this.iconData,
    required this.title,
    required this.body,
  });

  final IconData iconData;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
            color: DrivepalTokens.bgPrimary.withValues(alpha: 0.1),
            border: Border.all(
              color: DrivepalTokens.bgPrimary.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            iconData,
            color: DrivepalTokens.accentLink,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DrivepalShellTypography.elevatedInlineTitle(textTheme),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: DrivepalShellTypography.elevatedInlineBody(textTheme),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// In-panel empty / placeholder with icon disc + typography.
class DrivepalEmptyStateBlock extends StatelessWidget {
  const DrivepalEmptyStateBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DrivepalTokens.bgPrimary.withValues(alpha: 0.12),
                DrivepalTokens.bgPrimaryHover.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: DrivepalTokens.borderCard.withValues(alpha: 0.9),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 6),
                blurRadius: 16,
                color: DrivepalTokens.bgPrimary.withValues(alpha: 0.15),
              ),
            ],
          ),
          child: Icon(icon, size: 36, color: DrivepalTokens.accentLink),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: DrivepalShellTypography.emptyStateTitle(textTheme),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: DrivepalShellTypography.emptyStateBody(textTheme),
        ),
      ],
    );
  }
}

/// Context strip above the booking route card — same panel language as wallet/trips chrome.
class DrivepalMapContextRibbon extends StatelessWidget {
  const DrivepalMapContextRibbon({
    super.key,
    required this.body,
    this.semanticsLabel,
    this.maxLines = 4,
  });

  final String body;
  final String? semanticsLabel;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: semanticsLabel ?? body,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DrivepalTokens.bgCard.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusIsland),
          border: Border.all(
            color: DrivepalTokens.borderCard.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 4),
              color: DrivepalTokens.textHeading.withValues(alpha: 0.065),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.place_outlined,
                  size: 20,
                  color: DrivepalTokens.accentLink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  body,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: DrivepalShellTypography.mapContextRibbonBody(textTheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
