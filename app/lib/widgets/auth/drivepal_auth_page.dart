import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/drivepal_shadows.dart';
import '../../theme/drivepal_tokens.dart';
import '../drivepal_screen_typography.dart';
import 'drivepal_auth_tokens.dart';

/// Full-viewport auth shell: back row pinned [top], optional [pageTitle] / [pageSubtitle]
/// below it, then [child] top-aligned in the remaining space (scrolls if tall), optional [footer] + [bottomAction]
/// pinned [bottom].
class DrivepalAuthPage extends StatelessWidget {
  const DrivepalAuthPage({
    super.key,
    required this.child,
    this.footer,
    this.bottomAction,
    this.outerPadding,
    this.showBackBrandLabel = true,
    this.pageTitle,
    this.pageSubtitle,
  });

  final Widget child;
  final Widget? footer;
  final Widget? bottomAction;
  /// Replaces default horizontal [DrivepalAuthTokens.pageGutter] / top [DrivepalAuthTokens.authPageTopInset] when set.
  final EdgeInsetsGeometry? outerPadding;
  /// When false, back control is arrow only (no “DRIVEPAL” / brand label).
  final bool showBackBrandLabel;
  /// Shown under the back row (sentence case, same as landing — [DrivepalScreenHeadline]).
  final String? pageTitle;
  /// Optional lead line below [pageTitle] — same style as landing lead ([TextTheme.bodyLarge] muted).
  final String? pageSubtitle;

  @override
  Widget build(BuildContext context) {
    final h = DrivepalAuthTokens.pageGutter;
    final pad =
        outerPadding ??
        EdgeInsets.fromLTRB(
          h,
          DrivepalAuthTokens.authPageTopInset,
          h,
          12,
        );
    final EdgeInsets resolvedPad = pad is EdgeInsets
        ? pad
        : pad.resolve(Directionality.of(context));
    final double backLinkBottomGap = resolvedPad.top;

    return SafeArea(
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: DrivepalAuthTokens.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DrivepalAuthBackLink(showBrandLabel: showBackBrandLabel),
                    if (pageTitle != null) ...[
                      SizedBox(height: backLinkBottomGap),
                      DrivepalScreenHeadline(
                        pageTitle!,
                        textAlign: TextAlign.start,
                      ),
                      if (pageSubtitle != null) ...[
                        const SizedBox(height: 8),
                        DrivepalScreenLead(
                          pageSubtitle!,
                          textAlign: TextAlign.start,
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: DrivepalAuthTokens.maxContentWidth,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: footer!,
              ),
            if (bottomAction != null) bottomAction!,
          ],
        ),
      ),
    );
  }
}

/// `.drivepal-back-link.drivepal-back-link--brand` — arrow + optional brand label to home (or pop).
class DrivepalAuthBackLink extends StatelessWidget {
  const DrivepalAuthBackLink({
    super.key,
    this.label = 'DRIVEPAL',
    this.showBrandLabel = true,
  });

  final String label;
  final bool showBrandLabel;

  @override
  Widget build(BuildContext context) {
    if (!showBrandLabel) {
      return Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          style: IconButton.styleFrom(
            foregroundColor: DrivepalTokens.textHeading,
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: DrivepalTokens.textHeading,
          ),
        ),
      );
    }

    /// `.drivepal-back-link--brand` — 1.125rem, uppercase, `letter-spacing: 0.28em`
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      letterSpacing: 4.5,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: DrivepalTokens.textHeading,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        style: TextButton.styleFrom(
          foregroundColor: DrivepalTokens.textHeading,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: DrivepalTokens.textHeading,
        ),
        label: Text(label.toUpperCase(), style: titleStyle),
      ),
    );
  }
}

/// `.drivepal-card` shell. Optional [titleRow] renders in a light gray strip or, when
/// [titleRowOutlined] is true, a rounded inset panel with a gray border (signup).
/// [showShadow] is opt-in (default off).
///
/// [titleInsetPadding] / [contentPadding] tighten the signup layout when set.
class DrivepalAuthCard extends StatelessWidget {
  const DrivepalAuthCard({
    super.key,
    required this.child,
    this.titleRow,
    this.titleRowOutlined = false,
    this.titleInsetPadding,
    this.contentPadding,
    this.showShadow = false,
  });

  final Widget child;
  final Widget? titleRow;
  /// When true (e.g. create-account heading), [titleRow] sits in a rounded rect with
  /// [DrivepalTokens.borderInput] outline inside the card.
  final bool titleRowOutlined;
  /// Padding around the outlined title block (defaults to 12,12,12,0).
  final EdgeInsetsGeometry? titleInsetPadding;
  /// Inner padding for the form area (defaults to [DrivepalAuthTokens.cardPadding] on all sides).
  final EdgeInsetsGeometry? contentPadding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DrivepalAuthTokens.cardRadius);
    final titlePad =
        titleInsetPadding ?? const EdgeInsets.fromLTRB(12, 12, 12, 0);
    final bodyPad =
        contentPadding ??
        const EdgeInsets.all(DrivepalAuthTokens.cardPadding);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: DrivepalAuthTokens.borderCard),
        color: DrivepalTokens.bgCard,
        boxShadow: showShadow ? DrivepalShadows.card : const [],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titleRow != null)
              titleRowOutlined
                  ? Padding(
                      padding: titlePad,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DrivepalTokens.bgCardTitleBar,
                          borderRadius: BorderRadius.circular(
                            DrivepalTokens.radiusInput,
                          ),
                          border: Border.all(
                            color: DrivepalTokens.borderInput,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: titleRow,
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: DrivepalTokens.bgCardTitleBar,
                        border: Border(
                          bottom: BorderSide(
                            color: DrivepalTokens.borderCard,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DrivepalAuthTokens.cardPadding - 4,
                        vertical: 14,
                      ),
                      child: titleRow,
                    ),
            Padding(
              padding: bodyPad,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.drivepal-card__header` + `.drivepal-card__title` (+ optional `.drivepal-card__sub`).
/// [icon] is optional (e.g. plain “Create account” title).
class DrivepalAuthCardHeader extends StatelessWidget {
  const DrivepalAuthCardHeader({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 28,
                color: DrivepalTokens.accentIcon,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                /// `.drivepal-card__title` — 1.25rem, w600
                style: textTheme.titleLarge,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            /// `.drivepal-card__sub`
            style: textTheme.bodyMedium?.copyWith(
              color: DrivepalTokens.textMuted,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

/// `.drivepal-muted-footer`
class DrivepalAuthMutedFooter extends StatelessWidget {
  const DrivepalAuthMutedFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.only(top: DrivepalAuthTokens.footerTopGap),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: DrivepalTokens.textFaint,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
        child: child,
      ),
    );
  }
}

/// `.drivepal-banner-error` / `.drivepal-banner-info`
class DrivepalAuthBanner extends StatelessWidget {
  const DrivepalAuthBanner.error({super.key, required this.text}) : _isError = true;

  const DrivepalAuthBanner.info({super.key, required this.text}) : _isError = false;

  final String text;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    final color = _isError ? DrivepalTokens.textDanger : DrivepalTokens.textInfo;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}
