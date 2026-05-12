import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';

/// Screen title — same text role as landing “Mobile shell” (uses [TextTheme.headlineSmall]).
///
/// Avoid ad‑hoc [fontSize] here; tune [TextTheme.headlineSmall] in [buildDrivepalTheme] only.
class DrivepalScreenHeadline extends StatelessWidget {
  const DrivepalScreenHeadline(
    this.text, {
    super.key,
    this.uppercase = false,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final bool uppercase;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final display = uppercase ? text.toUpperCase() : text;
    return Text(
      display,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: uppercase ? 1.0 : -0.4,
        height: 1.25,
        color: DrivepalTokens.textHeading,
      ),
    );
  }
}

/// Muted intro under [DrivepalScreenHeadline] — same role as landing lead copy (uses [TextTheme.bodyLarge]).
class DrivepalScreenLead extends StatelessWidget {
  const DrivepalScreenLead(
    this.text, {
    super.key,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: DrivepalTokens.textMuted,
        height: 1.625,
      ),
    );
  }
}
