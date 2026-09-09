// ./lib/vocal/domain/models.dart

enum PianoRollDisplayMode { fullRange, singleOctave }

class PitchEvent {
  const PitchEvent({
    required this.startSeconds,
    required this.durationSeconds,
    required this.f0Hz,
  });

  final double startSeconds;
  final double durationSeconds;
  final double f0Hz;

  double get endSeconds => startSeconds + durationSeconds;

  factory PitchEvent.fromJson(Map<String, dynamic> json) {
    return PitchEvent(
      startSeconds: (json['time_s'] as num).toDouble(),
      durationSeconds: (json['duration'] as num).toDouble(),
      f0Hz: (json['f0_hz'] as num).toDouble(),
    );
  }
}

class LivePitch {
  const LivePitch({
    required this.timeSeconds,
    required this.frequencyHz,
    required this.confidence,
  });

  final double timeSeconds;
  final double frequencyHz;
  final double confidence;
}

class WaveformSample {
  const WaveformSample({required this.timeSeconds, required this.amplitude});

  final double timeSeconds;
  final double amplitude;
}
