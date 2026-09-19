// ./lib/vocal/presentation/classes.dart

import 'package:flutter/material.dart';

/// PianoRoll の色管理クラス
@immutable
final class PianoRollColors {
  const PianoRollColors({required this.colorScheme});

  final ColorScheme colorScheme;

  Color get background => colorScheme.surface;
  Color get alternateKey =>
      Color.lerp(colorScheme.surface, colorScheme.onSurface, .035) ??
      colorScheme.surface;
  Color get grid => colorScheme.outlineVariant.withValues(alpha: .28);
  Color get strongGrid => colorScheme.outline.withValues(alpha: .55);
  Color get primaryNote => Color(0xFF6CA6FF);
  Color get secondaryNote => colorScheme.secondary;
  Color get live => Color(0xFFFFC857);
  Color get match => Color(0xFF62E6A7);
  Color get playhead => Color(0xFFFF5B5B);
  Color get keyboard => Color(0xFFE8E8E8);
  Color get blackKey => Color(0xFF20242A);
  Color get keyboardLine => colorScheme.outline.withValues(alpha: .55);
  Color get label => colorScheme.onSurfaceVariant;
}

@immutable
final class WaveformColors {
  const WaveformColors({required this.colorScheme});

  final ColorScheme colorScheme;

  Color get background => colorScheme.surface;
  Color get grid => colorScheme.outlineVariant.withValues(alpha: .32);
  Color get reference => colorScheme.onSurfaceVariant;
  Color get mic => colorScheme.error;
  Color get match => colorScheme.tertiary;
  Color get playhead => colorScheme.primary;
}
