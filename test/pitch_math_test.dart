import 'package:flutter_test/flutter_test.dart';
import 'package:voice_note_app/shared/shared.dart';

void main() {
  test('440 Hz is MIDI 69', () {
    expect(frequencyToMidi(440), closeTo(69, 1e-9));
  });

  test('A4 +/- 100 cents maps around adjacent semitones', () {
    expect(frequencyToMidi(466.1637615), closeTo(70, 0.01));
    expect(frequencyToMidi(415.3046976), closeTo(68, 0.01));
  });
}
