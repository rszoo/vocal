import 'package:flutter_test/flutter_test.dart';
import 'package:voice_note_app/vocal/domain/models.dart';
import 'package:voice_note_app/vocal/services/pitch_matcher.dart';

void main() {
  // test('finds the active reference pitch', () {
  //   const matcher = PitchMatcher();
  //   const events = [PitchEvent(timeSec: 1, durationSec: 0.5, f0: 440)];

  //   final result = matcher.match(
  //     referenceEvents: events,
  //     timeSeconds: 1.2,
  //     frequencyHz: 440,
  //   );

  //   expect(result.matched, isTrue);
  //   expect(result.referenceEvent?.noteName, 'A4');
  // });

  // test('rejects a pitch outside the tolerance', () {
  //   const matcher = PitchMatcher(toleranceCents: 40);
  //   const events = [PitchEvent(timeSec: 1, durationSec: 0.5, f0: 440)];

  //   final result = matcher.match(
  //     referenceEvents: events,
  //     timeSeconds: 1.2,
  //     frequencyHz: 466.16,
  //   );

  //   expect(result.matched, isFalse);
  // });

  test('matches a live pitch to an active reference pitch', () {
    const matcher = PitchMatcher();
    final result = matcher.match(
      currentTime: 10.2,
      referenceEvents: const [
        PitchEvent(startSeconds: 10, durationSeconds: 1, f0Hz: 440),
      ],
      livePitches: const [
        LivePitch(timeSeconds: 10.2, frequencyHz: 440, confidence: 1),
      ],
    );

    expect(result.matchingIndices, contains(0));
  });

  test(
    'matches pitches in the same octave pitch class in single-octave mode',
    () {
      const matcher = PitchMatcher();
      final result = matcher.match(
        currentTime: 10.2,
        referenceEvents: const [
          PitchEvent(startSeconds: 10, durationSeconds: 1, f0Hz: 440),
        ],
        livePitches: const [
          LivePitch(timeSeconds: 10.2, frequencyHz: 220, confidence: 1),
        ],
        octaveOnly: true,
      );

      expect(result.matchingIndices, contains(0));
    },
  );
}
