class PitchResult {
  final double frequency;
  final String note;
  final int midiNote;
  final double cents;
  final double rms;

  const PitchResult({
    required this.frequency,
    required this.note,
    required this.midiNote,
    required this.cents,
    required this.rms,
  });

  bool get isInTune => cents.abs() < 5;

  bool get isSharp => cents >= 5;

  bool get isFlat => cents <= -5;

  String get tuningText {
    if (isInTune) {
      return 'ぴったり';
    }

    if (isSharp) {
      return '${cents.toStringAsFixed(1)} cent 高い';
    }

    return '${cents.abs().toStringAsFixed(1)} cent 低い';
  }
}
