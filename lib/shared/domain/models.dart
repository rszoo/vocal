import 'dart:math' as math;

/// ピッチ
class PitchSegment {
  const PitchSegment({
    required this.timeSec,
    required this.durationSec,
    required this.f0,
  });

  final double timeSec;
  final double durationSec;

  /// 基本周波数
  final double f0;

  double get endSec => timeSec + durationSec;

  double get midi => 69 + 12 * math.log(f0 / 440.0) / math.ln2;

  static double totalDurationSec(List<PitchSegment> pitches) {
    if (pitches.isEmpty) return 0;
    return pitches.map((e) => e.endSec).reduce((a, b) => a > b ? a : b);
  }
}
