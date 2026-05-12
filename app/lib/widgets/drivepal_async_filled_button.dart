import 'package:flutter/material.dart';

/// Primary [FilledButton.icon] with a shared loading state (spinner + disabled tap).
class DrivepalAsyncFilledButton extends StatelessWidget {
  const DrivepalAsyncFilledButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final String loadingLabel;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon:
          loading
              ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
              : icon,
      label: Text(loading ? loadingLabel : label),
    );
  }
}
