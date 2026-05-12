import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/drivepal_tokens.dart';
import '../../widgets/drivepal_shell_layout.dart';

/// Placeholder until real-time chat is implemented.
class ChatLandingScreen extends StatelessWidget {
  const ChatLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading:
            Navigator.of(context).canPop()
                ? IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => context.pop(),
                )
                : null,
        title: const Text('Messages'),
        centerTitle: false,
      ),
      body: DrivepalNarrowContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: 56,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                'Chat is coming soon',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DrivepalTokens.textHeading,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Text(
                'You’ll be able to message support and trip contacts from here. '
                "We're still building this—check back later.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DrivepalTokens.textBody,
                      height: 1.45,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
