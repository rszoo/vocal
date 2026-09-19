// ./lib/feature/monophony/fns.dart

import 'dart:math' as math;

import 'types.dart';

Midi convertF0ToMidi(F0 value) {
  assert(value > 0);
  var midi = convertF0ToMidiFloat(value).round();
  return midi;
}

double convertF0ToMidiFloat(F0 value) {
  assert(value > 0);
  var result = 69 + 12 * (math.log(value / 440) / math.ln2);
  return result;
}
