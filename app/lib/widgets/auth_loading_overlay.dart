import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/drivepal_tokens.dart';

/// Dimmed overlay with spinner — matches staff web [`.drivepal-busy-overlay`] + `.drivepal-spinner`.
class AuthLoadingOverlay extends StatelessWidget {
  const AuthLoadingOverlay({
    super.key,
    required this.visible,
    required this.message,
    required this.child,
  });

  final bool visible;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(absorbing: visible, child: child),
        if (visible)
          Positioned.fill(
            child: Semantics(
              label: message,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Material(
                    color: DrivepalTokens.bgOverlay,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 256),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DrivepalTokens.spinnerHead,
                                backgroundColor: DrivepalTokens.spinnerTrack,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: DrivepalTokens.textBody,
                                height: 1.625,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
