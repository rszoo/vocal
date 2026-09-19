// ./lib/shared/fns.dart

import 'dart:math' as math;

import 'package:collection/collection.dart';

extension NumListExtension<T extends num> on List<T> {
  double get mean {
    return average;
  }

  double get meansq {
    return map((value) => value * value).average;
  }

  double get rms {
    return math.sqrt(meansq);
  }

  int argmin(int from, int to) {
    assert(isNotEmpty);
    assert(from >= 0 && to < length, 'Index out of bounds');
    assert(from < to);
    var minIdx = from;
    for (var i = from + 1; i <= to; i++) {
      if (this[minIdx] > this[i]) minIdx = i;
    }
    return minIdx;
  }
}
