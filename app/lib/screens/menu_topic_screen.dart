import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';
import '../widgets/drivepal_tab_page_chrome.dart';

class _MenuTopicConfig {
  const _MenuTopicConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

const Map<String, _MenuTopicConfig> _menuTopicConfigs = {
  'help': _MenuTopicConfig(
    title: 'Help center',
    subtitle: 'FAQs, ride help, and support resources will appear here.',
    icon: Icons.help_outline_rounded,
  ),
  'terms': _MenuTopicConfig(
    title: 'Terms & conditions',
    subtitle: 'Service terms and rider/driver policies will be available here.',
    icon: Icons.gavel_rounded,
  ),
  'privacy': _MenuTopicConfig(
    title: 'Privacy policy',
    subtitle: 'How we collect and process your data will be listed here.',
    icon: Icons.privacy_tip_outlined,
  ),
  'contact': _MenuTopicConfig(
    title: 'Contact us',
    subtitle: 'Support contacts and response channels will show up here.',
    icon: Icons.support_agent_rounded,
  ),
  'feedback': _MenuTopicConfig(
    title: 'Feedback',
    subtitle: 'Share feature ideas and service feedback with our team.',
    icon: Icons.rate_review_outlined,
  ),
  'about': _MenuTopicConfig(
    title: 'About app',
    subtitle: 'App version, platform details, and release notes coming here.',
    icon: Icons.info_outline_rounded,
  ),
  'my-cars': _MenuTopicConfig(
    title: 'My Cars',
    subtitle: 'Your registered vehicles and approval details will appear here.',
    icon: Icons.directions_car_filled_rounded,
  ),
  'my-earning': _MenuTopicConfig(
    title: 'My Earning',
    subtitle: 'Trip payouts, balance summary, and earnings history will appear here.',
    icon: Icons.payments_rounded,
  ),
};

class MenuTopicScreen extends StatelessWidget {
  const MenuTopicScreen({
    super.key,
    required this.topic,
  });

  final String topic;

  @override
  Widget build(BuildContext context) {
    final config =
        _menuTopicConfigs[topic] ??
        const _MenuTopicConfig(
          title: 'Menu',
          subtitle: 'This section will be added soon.',
          icon: Icons.menu_rounded,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(config.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          DrivepalFeatureIntroCard(
            icon: config.icon,
            title: config.title,
            subtitle: config.subtitle,
          ),
          const SizedBox(height: 10),
          DrivepalElevatedPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
            child: const DrivepalEmptyStateBlock(
              icon: Icons.schedule_rounded,
              title: 'Coming soon',
              body:
                  'We are preparing this section. It will be available in a future update.',
            ),
          ),
        ],
      ),
      backgroundColor: DrivepalTokens.bgScaffold,
    );
  }
}

