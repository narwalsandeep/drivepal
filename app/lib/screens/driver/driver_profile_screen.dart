import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_session.dart';
import '../../services/driver_tab_refresh_notifier.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/profile/drivepal_profile_chrome.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  DriverTabRefreshNotifier? _tabRefreshNotifier;
  int _accountTabRefreshVersion = 0;

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(DriverTabIndex.account);
    if (nextVersion == _accountTabRefreshVersion) {
      return;
    }
    _accountTabRefreshVersion = nextVersion;
    unawaited(context.read<AuthSession>().reloadUserFromServer());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<DriverTabRefreshNotifier>();
    if (identical(notifier, _tabRefreshNotifier)) {
      return;
    }
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _tabRefreshNotifier = notifier;
    _accountTabRefreshVersion = notifier.versionFor(DriverTabIndex.account);
    notifier.addListener(_onTabRefreshTick);
  }

  @override
  void dispose() {
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final u = auth.user;
    final email = u?['email'] as String? ?? '';
    final first = u?['firstName'] as String? ?? '';
    final last = u?['lastName'] as String? ?? '';
    final profileDone = u?['driverProfileCompleted'] == true;
    final docStatus = (u?['driverDocumentStatus'] as String?) ?? 'pending';
    final docStatusLabel = switch (docStatus) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
    final initials = drivepalProfileInitials(first, last, email);
    final displayName = '$first $last'.trim();

    return ListView(
      padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
      children: [
        DrivepalProfileHero(
          initials: initials,
          displayName: displayName,
          email: email,
          roleLabel: DrivepalAppShellCopy.driverRoleLabel,
          profilePhotoBase64:
              (u?['driverProfilePhotoBase64'] ?? u?['profilePhotoBase64'])
                  as String?,
        ),
        if (!profileDone)
          DrivepalProfileSettingsTile(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Complete driver profile',
            subtitle: 'Required before accepting requests',
            onTap: () => context.push('/driver/onboarding'),
          ),
        const DrivepalProfileSectionLabel(DrivepalAppShellCopy.profileSectionProfile),
        DrivepalProfileSettingsTile(
          icon: Icons.edit_outlined,
          title: 'Edit driver profile',
          subtitle: 'Update profile, documents, and verification details',
          onTap: () => context.push('/driver/edit-profile'),
        ),
        const DrivepalProfileSectionLabel(
          DrivepalAppShellCopy.driverProfileSectionVerification,
        ),
        DrivepalProfileSettingsTile(
          icon: Icons.badge_outlined,
          title: DrivepalAppShellCopy.driverDocumentsTitle,
          subtitle:
              'Status: $docStatusLabel • Upload licence, update profile photo, and check approval',
          onTap: () => context.push('/driver/edit-profile'),
        ),
        const SizedBox(height: 12),
        DrivepalProfileLogoutTile(
          onTap: () async {
            final didConfirm = await showDrivepalLogoutConfirmDialog(context);
            if (!didConfirm || !context.mounted) {
              return;
            }
            await context.read<AuthSession>().logout();
            if (context.mounted) {
              context.go('/login');
            }
          },
        ),
      ],
    );
  }
}
