import 'package:flutter/material.dart';

import '../theme/drivepal_shadows.dart';
import '../theme/drivepal_tokens.dart';

/// Outer shadow for text fields and similar controls ([borderRadius] matches inputs).
///
/// When [focusNode] is set to the same node as a [TextField], the frame shows the
/// teal focus glow while focused ([DrivepalShadows.inputFocus]); otherwise a light
/// idle shadow ([DrivepalShadows.soft]).
class DrivepalSoftFrame extends StatelessWidget {
  const DrivepalSoftFrame({
    super.key,
    required this.child,
    this.borderRadius = DrivepalTokens.radiusInput,
    this.focusNode,
  });

  final Widget child;
  final double borderRadius;

  /// Must match [TextField.focusNode] (or [TextFormField]) for focus glow.
  final FocusNode? focusNode;

  List<BoxShadow> _shadows() {
    if (focusNode != null) {
      return focusNode!.hasFocus
          ? DrivepalShadows.inputFocus(DrivepalTokens.borderFocus)
          : DrivepalShadows.soft;
    }
    return DrivepalShadows.soft;
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: _shadows(),
    );

    if (focusNode == null) {
      return DecoratedBox(decoration: decoration, child: child);
    }

    return ListenableBuilder(
      listenable: focusNode!,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: _shadows(),
          ),
          child: child,
        );
      },
    );
  }
}
