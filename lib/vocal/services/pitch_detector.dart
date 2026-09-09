import 'dart:math' as math;
import 'dart:typed_data';

/// Monophonic pitch detector for PCM16 microphone frames.
///
/// YIN-style difference-function processing is used instead of selecting the
/// largest raw autocorrelation peak. This reduces octave/subharmonic jumps
/// that are common with a simple autocorrelation implementation.
class PitchDetector {
  const PitchDetector({
    this.minFrequency = 70,
    this.maxFrequency = 1000,
    this.threshold = 0.15,
  });

  final double minFrequency;
  final double maxFrequency;
  final double threshold;

  double? detect(Uint8List pcmBytes, int sampleRate) {
    final samples = _decodePcm16(pcmBytes);
    if (samples.length < 1024) return null;

    // Keep the analysis window bounded so real-time detection remains light
    // enough for Flutter Web while still covering low voices.
    final analysisSamples = samples.length > 4096
        ? samples.sublist(samples.length - 4096)
        : samples;
    final prepared = _prepareSamples(analysisSamples);
    if (prepared.isEmpty) return null;

    final minTau = math.max(2, (sampleRate / maxFrequency).floor());
    final maxTau = math.min(
      (sampleRate / minFrequency).ceil(),
      prepared.length ~/ 2,
    );
    if (maxTau <= minTau + 1) return null;

    final difference = List<double>.filled(maxTau + 1, 0.0);
    for (var tau = 1; tau <= maxTau; tau++) {
      var sum = 0.0;
      final limit = prepared.length - tau;
      for (var i = 0; i < limit; i++) {
        final delta = prepared[i] - prepared[i + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    // Cumulative mean normalized difference function.
    final cmnd = List<double>.filled(maxTau + 1, 1.0);
    var runningSum = 0.0;
    for (var tau = 1; tau <= maxTau; tau++) {
      runningSum += difference[tau];
      cmnd[tau] = runningSum <= 1e-12
          ? 1.0
          : difference[tau] * tau / runningSum;
    }

    var tau = _findFirstMinimum(cmnd, minTau, maxTau);
    if (tau == null) return null;

    // If the first dip is shallow, use the strongest local minimum instead
    // of accepting an unstable candidate.
    final candidate = tau;
    if (cmnd[candidate] > threshold) {
      tau = _findBestMinimum(cmnd, minTau, maxTau);
      if (tau == null || cmnd[tau] > threshold * 1.8) return null;
    }

    final refinedTau = _parabolicTau(cmnd, tau);
    if (refinedTau <= 0) return null;

    final frequency = sampleRate / refinedTau;
    if (frequency < minFrequency || frequency > maxFrequency) return null;

    final confidence = (1.0 - cmnd[tau]).clamp(0.0, 1.0).toDouble();
    if (confidence < 0.12) return null;
    return frequency;
  }

  int? _findFirstMinimum(List<double> cmnd, int minTau, int maxTau) {
    for (var tau = minTau + 1; tau < maxTau; tau++) {
      if (cmnd[tau] <= cmnd[tau - 1] && cmnd[tau] < cmnd[tau + 1]) {
        return tau;
      }
    }
    return _findBestMinimum(cmnd, minTau, maxTau);
  }

  int? _findBestMinimum(List<double> cmnd, int minTau, int maxTau) {
    var bestTau = -1;
    var bestValue = double.infinity;
    for (var tau = minTau; tau <= maxTau; tau++) {
      if (cmnd[tau] < bestValue) {
        bestValue = cmnd[tau];
        bestTau = tau;
      }
    }
    return bestTau < 0 ? null : bestTau;
  }

  double _parabolicTau(List<double> values, int tau) {
    if (tau <= 1 || tau >= values.length - 1) return tau.toDouble();
    final left = values[tau - 1];
    final center = values[tau];
    final right = values[tau + 1];
    final denominator = left - 2 * center + right;
    if (denominator.abs() < 1e-12) return tau.toDouble();
    final offset = 0.5 * (left - right) / denominator;
    return tau + offset.clamp(-0.5, 0.5);
  }

  List<double> _decodePcm16(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    final samples = List<double>.filled(sampleCount, 0);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  List<double> _prepareSamples(List<double> samples) {
    var mean = 0.0;
    for (final sample in samples) mean += sample;
    mean /= samples.length;

    final prepared = List<double>.filled(samples.length, 0);
    var energy = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i] - mean;
      prepared[i] = value;
      energy += value * value;
    }

    final rms = math.sqrt(energy / samples.length);
    if (rms < 0.008) return const [];
    return prepared;
  }
}
