import 'package:flutter/material.dart';

import '../domain/models.dart';

class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.microphoneEnabled,
    required this.waveformVisible,
    required this.pianoRollDisplayMode,
    required this.onMicrophonePressed,
    required this.onWaveformPressed,
    required this.onPianoRollDisplayModePressed,
  });

  final bool microphoneEnabled;
  final bool waveformVisible;
  final PianoRollDisplayMode pianoRollDisplayMode;
  final VoidCallback onMicrophonePressed;
  final VoidCallback onWaveformPressed;
  final VoidCallback onPianoRollDisplayModePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF11131A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF252936)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconToggle(
              tooltip: 'マイク',
              selected: microphoneEnabled,
              selectedColor: const Color(0xFFFF6B6B),
              icon: microphoneEnabled ? Icons.mic : Icons.mic_off,
              onPressed: onMicrophonePressed,
            ),
            _IconToggle(
              tooltip: '波形',
              selected: waveformVisible,
              icon: Icons.graphic_eq_rounded,
              onPressed: onWaveformPressed,
            ),
            const SizedBox(width: 8),
            const Text(
              'ピアノロール',
              softWrap: false,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<PianoRollDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: PianoRollDisplayMode.fullRange,
                  label: SizedBox(
                    width: 48,
                    child: Center(child: Text('C2–C7', softWrap: false)),
                  ),
                ),
                ButtonSegment(
                  value: PianoRollDisplayMode.singleOctave,
                  label: SizedBox(
                    width: 78,
                    child: Center(child: Text('1オクターブ', softWrap: false)),
                  ),
                ),
              ],
              selected: {pianoRollDisplayMode},
              onSelectionChanged: (_) => onPianoRollDisplayModePressed(),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onPressed,
    this.selectedColor,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: selected
            ? (selectedColor ?? const Color(0xFF42D3E6))
            : Colors.white54,
      ),
    );
  }
}
