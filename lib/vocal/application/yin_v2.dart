import 'dart:typed_data';

import '../../feature/monophony.dart';
import '../../shared/application/classes.dart';
import '../../shared/domain/yin_v0.dart';

/// YINアルゴリズムによるモノフォニック・ピッチ推定器
class YinV2 extends YinV0 {
  YinV2({
    required super.sampleRate,
    required super.frameSize,
    required super.minF0,
    required super.maxF0,
    required super.minConfidence,
    this.threshold = 0.15,
    this.fallbackThreshold = 0.28,
  }) : assert(threshold > 0 && threshold < 1),
       assert(fallbackThreshold > 0 && fallbackThreshold < 1),
       super();

  /// YINの絶対閾値
  final double threshold;

  /// フォールバック時に許容するCMNDの最大値
  final double fallbackThreshold;

  @override
  F0? detect(final Float32List samples) {
    final result = super.detect(samples);
    return result;
  }

  @override
  int? findTau(final Float32List cmnd) {
    if (cmnd.length < 3) return null;

    final start = minTau < 1 ? 1 : minTau;
    final end = maxTau < cmnd.length - 2 ? maxTau : cmnd.length - 2;
    if (start > end) return null;

    int? bestTau;
    var bestValue = double.infinity;

    for (var tau = start; tau <= end; tau++) {
      final left = cmnd[tau - 1];
      final current = cmnd[tau];
      final right = cmnd[tau + 1];

      if (!left.isFinite || !current.isFinite || !right.isFinite) {
        continue;
      }

      final isLocalMinimum = current < left && current <= right;
      if (!isLocalMinimum) continue;

      if (current < bestValue) {
        bestValue = current;
        bestTau = tau;
      }

      // thresholdを下回る最初の局所最小値を採用する。
      if (current < threshold) {
        return tau;
      }
    }

    // 品質が十分な最小の局所最小値をフォールバック候補にする
    if (bestTau == null || bestValue > fallbackThreshold) return null;
    return bestTau;
  }

  /// 放物線補間によるラグのサブサンプル推定
  @override
  double interpolateTau(final Float32List cmnd, final int tau) {
    return AudUtils.parabolicInterpolation(cmnd, tau, maxTau);
  }
}
