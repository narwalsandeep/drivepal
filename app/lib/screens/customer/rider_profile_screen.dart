import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_session.dart';
import '../../services/customer_tab_refresh_notifier.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/profile/drivepal_profile_chrome.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  CustomerTabRefreshNotifier? _tabRefreshNotifier;
  int _accountTabRefreshVersion = 0;

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(CustomerTabIndex.account);
    if (nextVersion == _accountTabRefreshVersion) {
      return;
    }
    _accountTabRefreshVersion = nextVersion;
    unawaited(context.read<AuthSession>().reloadUserFromServer());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<CustomerTabRefreshNotifier>();
    if (identical(notifier, _tabRefreshNotifier)) {
      return;
    }
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _tabRefreshNotifier = notifier;
    _accountTabRefreshVersion = notifier.versionFor(CustomerTabIndex.account);
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
    final initials = drivepalProfileInitials(first, last, email);
    final displayName = '$first $last'.trim();

    return ListView(
      padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
      children: [
        DrivepalProfileHero(
          initials: initials,
          displayName: displayName,
          email: email,
          roleLabel: DrivepalAppShellCopy.riderRoleLabel,
          profilePhotoBase64: u?['profilePhotoBase64'] as String?,
        ),
        const DrivepalProfileSectionLabel(DrivepalAppShellCopy.profileSectionProfile),
        DrivepalProfileSettingsTile(
          icon: Icons.edit_outlined,
          title: DrivepalAppShellCopy.profileEditTitle,
          subtitle: DrivepalAppShellCopy.profileEditSubtitle,
          onTap: () => context.push('/customer/edit-profile'),
        ),
        const DrivepalProfileSectionLabel(
          DrivepalAppShellCopy.profileSectionSettings,
        ),
        DrivepalProfileSettingsTile(
          icon: Icons.lock_outline_rounded,
          title: DrivepalAppShellCopy.profileChangePasswordTitle,
          subtitle: DrivepalAppShellCopy.profileChangePasswordSubtitle,
          onTap: () => context.push('/customer/change-password'),
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
