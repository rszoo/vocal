// ./lib/voice/application/classes.dart

import 'dart:typed_data';

import '../../shared/application/classes.dart';
import '../domain/models.dart';
import 'yin_v1.dart';

class PitchDetection {
  PitchDetection({
    required int sampleRate,
    required int frameSize,
    required int minF0,
    required int maxF0,
    required double minConfidence,
    // int minRms = 600,
  }) : // assert(minRms > 0),
       // rmsThreshold = minRms / pcm16MaxAbs,
       _detection = YinV1(
         sampleRate: sampleRate,
         frameSize: frameSize,
         minF0: minF0,
         maxF0: maxF0,
         minConfidence: minConfidence,
       ),
       super();

  // final double rmsThreshold;

  final YinV1 _detection;

  VoiceData estimate(final Float32List samples) {
    final level = AudUtils.measureAcAmp(samples);
    final pitch = _detection.detect(samples);
    final result = VoiceData.from(
      isVoice: (pitch != null),
      pitch: pitch ?? 0.0,
      level: level,
    );
    return result;
  }
}
