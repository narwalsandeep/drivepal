import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Circular elevated control for [AppBar.leading] (rides/drive-style chrome).
///
/// Pass [onPressed] for tab “back to home” (e.g. [StatefulNavigationShell.goBranch](0)).
/// If [onPressed] is null, the button appears only when [context.canPop] and pops the route.
Widget? buildDrivepalCircleBackLeading(
  BuildContext context, {
  VoidCallback? onPressed,
  String tooltip = 'Back',
}) {
  final canPop = context.canPop();
  final show = onPressed != null || canPop;
  if (!show) return null;

  void handleTap() {
    if (onPressed != null) {
      onPressed();
    } else {
      context.pop();
    }
  }

  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsetsDirectional.only(start: 10),
    child: Center(
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: handleTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                color: scheme.onSurface,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
