// ./lib/vocal/fns.dart

const tempoBpm = 120;

const beatsPerMeasure = 4;

const pianoRollKeyboardWidth = 56.0;

const pianoRollRulerHeight = 28.0;

bool isNaturalNote(int midi) {
  return !isAccidentalNote(midi);
}

bool isAccidentalNote(int midi) {
  return switch (midi % 12) {
    1 || 3 || 6 || 8 || 10 => true,
    _ => false,
  };
}

String formatTime(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  final minutes = total ~/ 60;
  final secs = total % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}
