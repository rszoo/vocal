import 'dart:math' as math;

/// Stabilizes frame-to-frame monophonic pitch estimates without flattening
/// legitimate musical movement.
class PitchStabilizer {
  PitchStabilizer({
    this.smoothing = 0.45,
    this.maxJumpCents = 900,
    this.octaveCorrectionCents = 180,
    this.holdFrames = 2,
  });

  /// Smoothing amount in log-frequency space. Larger values follow the input
  /// faster; smaller values suppress jitter more strongly.
  final double smoothing;
  final double maxJumpCents;
  final double octaveCorrectionCents;
  final int holdFrames;

  double? _lastStableHz;
  int _missingFrames = 0;

  double? process(double? frequencyHz) {
    if (frequencyHz == null ||
        !frequencyHz.isFinite ||
        frequencyHz <= 0) {
      if (_lastStableHz != null && _missingFrames < holdFrames) {
        _missingFrames++;
        return _lastStableHz;
      }
      _missingFrames = 0;
      return null;
    }

    _missingFrames = 0;
    var candidate = frequencyHz;

    if (_lastStableHz != null) {
      final previous = _lastStableHz!;
      final direct = _cents(candidate, previous);

      // A common pitch-detector failure is exactly one octave high/low.
      if (direct > octaveCorrectionCents) {
        final half = candidate / 2;
        final doubled = candidate * 2;
        final halfDistance = _cents(half, previous);
        final doubledDistance = _cents(doubled, previous);

        if (halfDistance <= octaveCorrectionCents) {
          candidate = half;
        } else if (doubledDistance <= octaveCorrectionCents) {
          candidate = doubled;
        }
      }

      final correctedDistance = _cents(candidate, previous);
      if (correctedDistance > maxJumpCents) {
        // Do not draw a single-frame vertical spike caused by noise.
        return previous;
      }

      // Smooth in log-frequency space. Unlike the previous median-history
      // implementation, this does not replace the history with the median,
      // so real pitch changes are preserved.
      final alpha = smoothing.clamp(0.0, 1.0).toDouble();
      final ratio = candidate / previous;
      candidate = previous * math.pow(ratio, alpha).toDouble();
    }

    _lastStableHz = candidate;
    return candidate;
  }

  void reset() {
    _lastStableHz = null;
    _missingFrames = 0;
  }

  double _cents(double a, double b) =>
      (1200 * math.log(a / b) / math.ln2).abs();
}
