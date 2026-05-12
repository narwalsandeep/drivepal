import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';
import '../widgets/drivepal_tab_page_chrome.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.roleLabel,
  });

  final String roleLabel;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _pushAlerts = true;
  bool _tripStatusAlerts = true;
  bool _paymentAlerts = true;
  bool _promotions = false;
  bool _shareLiveTrip = true;
  bool _biometricLock = false;
  bool _darkMapDuringRide = false;
  String _distanceUnit = 'Kilometers';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          DrivepalFeatureIntroCard(
            icon: Icons.settings_suggest_rounded,
            title: 'Personalize your app',
            subtitle:
                'Manage alerts, trip preferences, privacy, and safety controls for your ${widget.roleLabel.toLowerCase()} account.',
          ),
          const SizedBox(height: 8),
          const DrivepalProfileSectionLabel('Notifications'),
          DrivepalElevatedPanel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Push alerts',
                  subtitle: 'Enable app notifications',
                  value: _pushAlerts,
                  onChanged: (v) => setState(() => _pushAlerts = v),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  title: 'Trip status updates',
                  subtitle: 'Driver accepted, arrived, completed',
                  value: _tripStatusAlerts,
                  onChanged: (v) => setState(() => _tripStatusAlerts = v),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  title: 'Payment alerts',
                  subtitle: 'Receipts and transaction updates',
                  value: _paymentAlerts,
                  onChanged: (v) => setState(() => _paymentAlerts = v),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  title: 'Offers and promotions',
                  subtitle: 'Occasional deals and campaign updates',
                  value: _promotions,
                  onChanged: (v) => setState(() => _promotions = v),
                ),
              ],
            ),
          ),
          const DrivepalProfileSectionLabel('Trip Preferences'),
          DrivepalElevatedPanel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                _DropdownRow(
                  title: 'Distance unit',
                  subtitle: 'Used for fare estimates and route details',
                  value: _distanceUnit,
                  options: const ['Kilometers', 'Miles'],
                  onChanged: (v) {
                    if (v != null) setState(() => _distanceUnit = v);
                  },
                ),
                const Divider(height: 1),
                _SwitchRow(
                  title: 'Dark map during ride',
                  subtitle: 'Reduce map glare at night',
                  value: _darkMapDuringRide,
                  onChanged: (v) => setState(() => _darkMapDuringRide = v),
                ),
              ],
            ),
          ),
          const DrivepalProfileSectionLabel('Privacy & Safety'),
          DrivepalElevatedPanel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Share live trip with trusted contacts',
                  subtitle: 'Safety link while ride is active',
                  value: _shareLiveTrip,
                  onChanged: (v) => setState(() => _shareLiveTrip = v),
                ),
                const Divider(height: 1),
                _SwitchRow(
                  title: 'Biometric app lock',
                  subtitle: 'Require face/fingerprint to open app',
                  value: _biometricLock,
                  onChanged: (v) => setState(() => _biometricLock = v),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: DrivepalTokens.bgScaffold,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: DrivepalTokens.textHeading,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: DrivepalTokens.textOnPrimary,
            activeTrackColor: DrivepalTokens.bgPrimary,
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: DrivepalTokens.textHeading,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DrivepalTokens.textMuted,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              borderRadius: BorderRadius.circular(DrivepalTokens.radiusInput),
              dropdownColor: DrivepalTokens.bgCard,
              items: [
                for (final option in options)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DrivepalTokens.textHeading,
                          ),
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

