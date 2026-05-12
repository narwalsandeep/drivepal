import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import '../../services/alerts_unread_monitor.dart';
import '../../services/customer_tab_refresh_notifier.dart';
import '../../services/driver_tab_refresh_notifier.dart';
import '../../services/notifications_api.dart';
import '../../theme/drivepal_app_shell_copy.dart';
import '../../widgets/drivepal_shell_layout.dart';
import '../../widgets/drivepal_tab_page_chrome.dart';
import '../../widgets/alerts/drivepal_alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.notificationsApi});

  final NotificationsApi? notificationsApi;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final NotificationsApi _notificationsApi =
      widget.notificationsApi ?? NotificationsApi();
  List<RiderNotificationItem> _items = const <RiderNotificationItem>[];
  bool _loading = false;
  bool _unreadOnly = false;
  String? _error;
  int _unreadCount = 0;
  CustomerTabRefreshNotifier? _tabRefreshNotifier;
  DriverTabRefreshNotifier? _driverTabRefreshNotifier;
  int _alertsTabRefreshVersion = 0;
  int _driverAlertsTabRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlerts());
  }

  void _onTabRefreshTick() {
    final notifier = _tabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(CustomerTabIndex.alerts);
    if (nextVersion == _alertsTabRefreshVersion) {
      return;
    }
    _alertsTabRefreshVersion = nextVersion;
    unawaited(_loadAlerts());
  }

  void _onDriverTabRefreshTick() {
    final notifier = _driverTabRefreshNotifier;
    if (notifier == null || !mounted) {
      return;
    }
    final nextVersion = notifier.versionFor(DriverTabIndex.alerts);
    if (nextVersion == _driverAlertsTabRefreshVersion) {
      return;
    }
    _driverAlertsTabRefreshVersion = nextVersion;
    unawaited(_loadAlerts());
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
    _alertsTabRefreshVersion = notifier.versionFor(CustomerTabIndex.alerts);
    notifier.addListener(_onTabRefreshTick);

    final driverNotifier = context.read<DriverTabRefreshNotifier>();
    if (identical(driverNotifier, _driverTabRefreshNotifier)) {
      return;
    }
    _driverTabRefreshNotifier?.removeListener(_onDriverTabRefreshTick);
    _driverTabRefreshNotifier = driverNotifier;
    _driverAlertsTabRefreshVersion = driverNotifier.versionFor(
      DriverTabIndex.alerts,
    );
    driverNotifier.addListener(_onDriverTabRefreshTick);
  }

  @override
  void dispose() {
    _tabRefreshNotifier?.removeListener(_onTabRefreshTick);
    _driverTabRefreshNotifier?.removeListener(_onDriverTabRefreshTick);
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    final authSession = context.read<AuthSession>();
    final unreadMonitor = context.read<AlertsUnreadMonitor>();
    final token = await authSession.getValidAccessToken();
    if (token == null) {
      unreadMonitor.syncUnreadCount(0);
      setState(() {
        _items = const <RiderNotificationItem>[];
        _error = 'Please sign in again to load alerts.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _notificationsApi.listMine(
        bearerToken: token,
        unreadOnly: _unreadOnly,
      );
      if (!mounted) return;
      unreadMonitor.syncUnreadCount(res.unreadCount);
      setState(() {
        _items = res.items;
        _unreadCount = res.unreadCount;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead(RiderNotificationItem item) async {
    if (item.isRead) {
      return;
    }
    final token = await context.read<AuthSession>().getValidAccessToken();
    if (token == null) {
      _showBottomMessage('Please sign in again to update alerts.');
      return;
    }
    try {
      final res = await _notificationsApi.markRead(
        bearerToken: token,
        notificationId: item.id,
      );
      if (!mounted) {
        return;
      }
      context.read<AlertsUnreadMonitor>().syncUnreadCount(res.unreadCount);
      setState(() {
        _items = res.items;
        _unreadCount = res.unreadCount;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showBottomMessage(e.message);
    }
  }

  void _showBottomMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _timeAgo(DateTime dt) {
    final delta = DateTime.now().difference(dt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes} min ago';
    if (delta.inDays < 1) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sectionTitle =
        _unreadOnly
            ? DrivepalAppShellCopy.riderAlertsSectionUnread
            : DrivepalAppShellCopy.riderAlertsSectionAll;
    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView(
        padding: drivepalFloatingShellBodyPadding(context, extraBottom: 8),
        children: [
          const DrivepalFeatureIntroCard(
            icon: Icons.notifications_active_rounded,
            title: DrivepalAppShellCopy.riderAlertsIntroTitle,
            subtitle: DrivepalAppShellCopy.riderAlertsIntroSubtitle,
          ),
          const SizedBox(height: 8),
          DrivepalProfileSectionLabel(sectionTitle),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text(DrivepalAppShellCopy.riderAlertsFilterAll),
                selected: !_unreadOnly,
                onSelected: (selected) {
                  if (!selected || !_unreadOnly) {
                    return;
                  }
                  setState(() => _unreadOnly = false);
                  _loadAlerts();
                },
              ),
              ChoiceChip(
                label: Text(
                  '${DrivepalAppShellCopy.riderAlertsFilterUnread} ($_unreadCount)',
                ),
                selected: _unreadOnly,
                onSelected: (selected) {
                  if (!selected || _unreadOnly) {
                    return;
                  }
                  setState(() => _unreadOnly = true);
                  _loadAlerts();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const DrivepalElevatedPanel(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_error != null)
            DrivepalElevatedPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _loadAlerts,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_items.isEmpty)
            const DrivepalElevatedPanel(
              child: DrivepalEmptyStateBlock(
                icon: Icons.notifications_none_rounded,
                title: DrivepalAppShellCopy.riderAlertsEmptyTitle,
                body: DrivepalAppShellCopy.riderAlertsEmptyBody,
              ),
            )
          else
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DrivepalAlertCard(
                  item: item,
                  timeLabel: _timeAgo(item.createdAt),
                  onTap: () => _markAsRead(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
