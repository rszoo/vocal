// ./test/feature/monophony_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_note_app/feature/monophony.dart';

void main() {
  group('frequencyToMidi', () {
    test('440 Hz is MIDI 69', () {
      expect(convertF0ToMidi(440), closeTo(69, 1e-9));
    });

    test('A4 +/- 100 cents maps around adjacent semitones', () {
      expect(convertF0ToMidi(466.1637615), closeTo(70, 0.01));
      expect(convertF0ToMidi(415.3046976), closeTo(68, 0.01));
    });
  });
}
