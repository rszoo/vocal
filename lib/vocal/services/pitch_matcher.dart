import 'dart:math' as math;

import '../domain/models.dart';

class PitchMatchResult {
  const PitchMatchResult({required this.matchingIndices});

  final Set<int> matchingIndices;
}

class PitchMatcher {
  const PitchMatcher({this.toleranceCents = 60});

  final double toleranceCents;

  PitchMatchResult match({
    required double currentTime,
    required List<PitchEvent> referenceEvents,
    required List<LivePitch> livePitches,
    bool octaveOnly = false,
  }) {
    final indices = <int>{};
    final activeLive = livePitches
        .where((pitch) => (currentTime - pitch.timeSeconds).abs() < 0.35)
        .toList();

    for (var i = 0; i < referenceEvents.length; i++) {
      final reference = referenceEvents[i];
      if (currentTime < reference.startSeconds ||
          currentTime > reference.endSeconds) {
        continue;
      }

      for (final live in activeLive) {
        final cents = octaveOnly
            ? _octaveCentsDifference(live.frequencyHz, reference.f0Hz)
            : _centsDifference(live.frequencyHz, reference.f0Hz);
        if (cents <= toleranceCents) {
          indices.add(i);
          break;
        }
      }
    }

    return PitchMatchResult(matchingIndices: indices);
  }

  double _centsDifference(double a, double b) {
    return (1200 * math.log(a / b) / math.ln2).abs();
  }

  double _octaveCentsDifference(double a, double b) {
    final cents = _centsDifference(a, b) % 1200;
    return math.min(cents, 1200 - cents);
  }
}
