import 'package:flutter/material.dart';

import '../theme/drivepal_layout.dart';
import '../theme/drivepal_tokens.dart';

/// Two-option control (Rider / Driver): borderless track, animated sliding thumb,
/// same height and corner radius as primary buttons ([DrivepalLayout.controlHeight],
/// [DrivepalTokens.radiusButton]).
///
/// For more than two segments, falls back to [SegmentedButton] with no outline.
class DrivepalPillToggle<T extends Object> extends StatelessWidget {
  const DrivepalPillToggle({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelectionEnabled = false,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool multiSelectionEnabled;

  int _selectedIndex() {
    if (selected.isEmpty || segments.isEmpty) return 0;
    final v = selected.first;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].value == v) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (segments.length != 2 || multiSelectionEnabled) {
      return Theme(
        data: Theme.of(context).copyWith(
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DrivepalTokens.radiusButton),
                ),
              ),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: DrivepalLayout.controlHeight,
          child: SegmentedButton<T>(
            segments: segments,
            selected: selected,
            onSelectionChanged: onSelectionChanged,
            multiSelectionEnabled: multiSelectionEnabled,
            showSelectedIcon: false,
          ),
        ),
      );
    }

    final idx = _selectedIndex().clamp(0, 1);

    void select(int i) {
      if (i < 0 || i >= segments.length) return;
      final v = segments[i].value;
      if (selected.contains(v)) return;
      onSelectionChanged({v});
    }

    const thumbPad = 4.0;
    final thumbRadius = DrivepalTokens.radiusButton - thumbPad;

    return SizedBox(
      height: DrivepalLayout.controlHeight,
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(thumbPad),
        decoration: BoxDecoration(
          /// Slate-100 track — borderless group behind sliding thumb.
          color: DrivepalTokens.bgCardTitleBar,
          borderRadius: BorderRadius.circular(DrivepalTokens.radiusButton),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final segW = w / 2;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: idx * segW,
                  top: 0,
                  width: segW,
                  height: h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DrivepalTokens.bgPrimary,
                      borderRadius: BorderRadius.circular(thumbRadius),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SegmentCell<T>(
                        segment: segments[0],
                        selected: idx == 0,
                        onTap: () => select(0),
                      ),
                    ),
                    Expanded(
                      child: _SegmentCell<T>(
                        segment: segments[1],
                        selected: idx == 1,
                        onTap: () => select(1),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SegmentCell<T extends Object> extends StatelessWidget {
  const _SegmentCell({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final ButtonSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onThumb = DrivepalTokens.textOnPrimary;
    final idle = DrivepalTokens.textMuted;
    final color = selected ? onThumb : idle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: segment.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DrivepalTokens.radiusButton),
        splashColor: DrivepalTokens.bgPrimary.withValues(alpha: 0.15),
        highlightColor: DrivepalTokens.bgPrimary.withValues(alpha: 0.08),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                IconTheme.merge(
                  data: IconThemeData(color: color, size: 22),
                  child: segment.icon!,
                ),
                const SizedBox(width: 6),
              ],
              if (segment.label != null)
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.15,
                    color: color,
                  ),
                  child: segment.label!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
