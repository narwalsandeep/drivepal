import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/drivepal_app_shell_copy.dart';
import '../../theme/drivepal_tokens.dart';

/// Shared initials helper for rider / driver profile screens.
String drivepalProfileInitials(String first, String last, String email) {
  final a = first.isNotEmpty ? first[0] : '';
  final b = last.isNotEmpty ? last[0] : '';
  if (a.isNotEmpty && b.isNotEmpty) {
    return '${a.toUpperCase()}${b.toUpperCase()}';
  }
  if (a.isNotEmpty) return a.toUpperCase();
  if (email.isNotEmpty) return email[0].toUpperCase();
  return '?';
}

/// Square face fill (clip + photo or initials) — border lives on the parent frame.
class _SquareAvatarFace extends StatelessWidget {
  const _SquareAvatarFace({
    required this.side,
    required this.initials,
    this.profilePhotoBase64,
  });

  final double side;
  final String initials;
  final String? profilePhotoBase64;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(DrivepalTokens.radiusCard);
    final b64 = profilePhotoBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return ClipRRect(
          borderRadius: r,
          child: Image.memory(
            bytes,
            width: side,
            height: side,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: side,
        height: side,
        color: DrivepalTokens.bgCard,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: DrivepalTokens.bgPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header block: gradient card, square avatar (left), name / role / email (right).
class DrivepalProfileHero extends StatelessWidget {
  const DrivepalProfileHero({
    super.key,
    required this.initials,
    required this.displayName,
    required this.email,
    this.roleLabel,
    this.profilePhotoBase64,
  });

  final String initials;
  final String displayName;
  final String email;

  /// Optional JPEG base64 (see [compressProfilePhotoToJpegBase64]) — device-local until server upload exists.
  final String? profilePhotoBase64;

  /// Short label, e.g. `Rider` / `Driver` — shown as an uppercase chip.
  final String? roleLabel;

  /// Matches elevated tiles ([DrivepalProfileSettingsTile], feature intro icons).
  static const double _avatarSide = 72;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nameTrim = displayName.trim();
    final hasRole = roleLabel != null && roleLabel!.isNotEmpty;
    final radius = BorderRadius.circular(DrivepalTokens.radiusCard);

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
        border: Border.all(
          color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
        ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: DrivepalTokens.bgPrimary.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              child: SizedBox(
                width: _avatarSide,
                height: _avatarSide,
                child: _SquareAvatarFace(
                  side: _avatarSide,
                  initials: initials,
                  profilePhotoBase64: profilePhotoBase64,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (nameTrim.isNotEmpty)
                    Text(
                      nameTrim,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DrivepalTokens.textHeading,
                        letterSpacing: -0.4,
                      ),
                    ),
                  if (hasRole) ...[
                    if (nameTrim.isNotEmpty) const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _RoleChip(label: roleLabel!),
                    ),
                  ],
                  if (email.isNotEmpty) ...[
                    SizedBox(height: (nameTrim.isNotEmpty || hasRole) ? 8 : 0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.alternate_email_rounded,
                            size: 16,
                            color: DrivepalTokens.textMuted.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            textAlign: TextAlign.start,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: DrivepalTokens.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
        border: Border.all(color: DrivepalTokens.borderCard),
        color: DrivepalTokens.bgInput,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.35,
            fontWeight: FontWeight.w800,
            color: DrivepalTokens.accentLink,
          ),
        ),
      ),
    );
  }
}

/// Section label — monospace feel via letter-spacing (tech / dashboard).
class DrivepalProfileSectionLabel extends StatelessWidget {
  const DrivepalProfileSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.25,
            fontWeight: FontWeight.w700,
            color: DrivepalTokens.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Tappable settings row with icon tile, hairline border, soft lift.
class DrivepalProfileSettingsTile extends StatelessWidget {
  const DrivepalProfileSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: DrivepalTokens.bgCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
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
                    child: Icon(icon, color: DrivepalTokens.accentLink, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DrivepalTokens.textHeading,
                            letterSpacing: -0.15,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: DrivepalTokens.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: DrivepalTokens.textFaint,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive / sign-out row with accent rail — matches premium app patterns.
class DrivepalProfileLogoutTile extends StatelessWidget {
  const DrivepalProfileLogoutTile({
    super.key,
    required this.onTap,
    this.label = DrivepalAppShellCopy.actionLogout,
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
            border: Border.all(
              color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
            ),
            color: DrivepalTokens.bgCard,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 10,
                color: DrivepalTokens.textDanger.withValues(alpha: 0.06),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(DrivepalTokens.radiusCard),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        DrivepalTokens.textDanger,
                        DrivepalTokens.textDanger.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: DrivepalTokens.textDanger.withValues(alpha: 0.95),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: textTheme.titleSmall?.copyWith(
                            color: DrivepalTokens.textDanger,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showDrivepalLogoutConfirmDialog(BuildContext context) async {
  final didConfirm =
      await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: DrivepalTokens.bgCard,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DrivepalTokens.radiusCard),
              side: BorderSide(
                color: DrivepalTokens.borderCard.withValues(alpha: 0.95),
              ),
            ),
            title: Row(
              children: [
                const Expanded(child: Text('Log out?')),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            content: const Text('Are you sure you want to log out now?'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Log out'),
              ),
            ],
          );
        },
      ) ??
      false;
  return didConfirm;
}
