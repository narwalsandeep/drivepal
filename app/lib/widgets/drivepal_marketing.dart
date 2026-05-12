import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';
import 'auth/drivepal_auth_tokens.dart';
import 'drivepal_screen_typography.dart';
import 'drivepal_shell_layout.dart';

/// Scaffold + SafeArea + centered scroll + [DrivepalNarrowContent] — same shell width as auth.
class DrivepalLandingShell extends StatelessWidget {
  const DrivepalLandingShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: DrivepalAuthTokens.sectionGapMd,
            ),
            child: DrivepalNarrowContent(child: child),
          ),
        ),
      ),
    );
  }
}

class DrivepalBrandMark extends StatelessWidget {
  const DrivepalBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      'DRIVEPAL',
      textAlign: TextAlign.center,
      style: textTheme.titleSmall?.copyWith(
        letterSpacing: 5.6,
        fontWeight: FontWeight.w600,
        color: DrivepalTokens.textHeading,
      ),
    );
  }
}

class DrivepalLandingRoleIconRow extends StatelessWidget {
  const DrivepalLandingRoleIconRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_rounded, size: 40, color: DrivepalTokens.accentIcon),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.sync_alt_rounded,
            size: 22,
            color: DrivepalTokens.accentIcon.withValues(alpha: 0.75),
          ),
        ),
        Icon(Icons.local_taxi_rounded, size: 40, color: DrivepalTokens.accentIcon),
      ],
    );
  }
}

class DrivepalLandingHeadline extends StatelessWidget {
  const DrivepalLandingHeadline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DrivepalScreenHeadline(text);
  }
}

class DrivepalLandingLead extends StatelessWidget {
  const DrivepalLandingLead(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DrivepalScreenLead(text);
  }
}

/// Sign up / Sign in / Forgot — spacing from shared tokens.
class DrivepalLandingAuthActions extends StatelessWidget {
  const DrivepalLandingAuthActions({
    super.key,
    required this.onSignUp,
    required this.onSignIn,
    required this.onForgotPassword,
  });

  final VoidCallback onSignUp;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onSignUp,
          icon: const Icon(Icons.app_registration_rounded, size: 20),
          label: const Text('Sign up'),
        ),
        SizedBox(height: DrivepalAuthTokens.sectionGapSm),
        OutlinedButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login_rounded, size: 20),
          label: const Text('Sign in'),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: DrivepalTokens.textFaint,
          ),
          icon: Icon(
            Icons.lock_reset_rounded,
            size: 18,
            color: DrivepalTokens.textFaint,
          ),
          label: const Text('Forgot password?'),
        ),
      ],
    );
  }
}
