// ./lib/voice/application/yin_v1.dart

import 'dart:typed_data';

import '../../shared/application/classes.dart';
import '../../shared/domain/yin_v0.dart';
import '../../shared/fns.dart' as fns;

class YinV1 extends YinV0 {
  YinV1({
    required super.sampleRate,
    required super.frameSize,
    required super.minF0,
    required super.maxF0,
    required super.minConfidence,
    this.threshold = 0.15,
  }) : assert(threshold > 0 && threshold < 1),
       super();

  /// YINの絶対閾値
  final double threshold;

  @override
  double? detect(final Float32List samples) {
    final result = super.detect(samples);
    return result;
  }

  @override
  int? findTau(final Float32List cmnd) {
    // Threshold: 最初の谷を優先する
    int? tauEstimate;

    // YINのfirst threshold crossing + local minimum
    for (var tau = minTau; tau <= maxTau; tau++) {
      if (cmnd[tau] < threshold) {
        while (tau + 1 <= maxTau && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        tauEstimate = tau;
        break;
      }
    }

    // thresholdに入らない場合は global minimum をフォールバックとして使用
    if (tauEstimate == null) {
      // NumListExtension の argmin を使って指定範囲の最小値のインデックスを一発で取得
      final bestTau = cmnd.argmin(minTau, maxTau);
      final minimum = cmnd[bestTau];

      // 3/4 の棄却条件を維持
      if (minimum > 0.35) return null;

      tauEstimate = bestTau;
    }

    return tauEstimate;
  }

  @override
  double interpolateTau(final Float32List cmnd, final int tau) {
    return AudUtils.parabolicInterpolation(cmnd, tau, maxTau);
  }
}
