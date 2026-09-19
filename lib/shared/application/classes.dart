// ./lib/shared/application/classes.dart

import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../feature/monophony.dart';

/// 音声信号処理に関する数学・統計ユーティリティ
abstract final class AudUtils {
  /// 許容する最低F0 [Hz]
  static const minF0 = 65;

  /// 許容する最高F0 [Hz]
  static const maxF0 = 1050;

  static const eps = 1e-10;

  static double measureAcAmpInDb(AudioFrame frame) {
    // AC振幅
    final value = measureAcAmp(frame);
    // 10^(-120 / 20) = 1e-6
    if (value <= 1e-6) return -120;

    // dB変換
    final result = _convertDecibels(value);
    return result;
  }

  /// 音声フレームの交流振幅（AC振幅 / 二乗平均平方根）を計算
  static double measureAcAmp(AudioFrame frame) {
    if (frame.isEmpty || frame.isInvalid) return 0;

    // DC成分（フレーム内の平均値）
    final mean = frame.average;

    // DC成分を除いた平均平方
    final meansq = frame.map((sample) {
      final diff = sample - mean;
      return diff * diff;
    }).average;

    final result = math.sqrt(meansq);
    return result;
  }

  /// Parabolic Interpolation（サブサンプル補間）
  static double parabolicInterpolation(
    AudioFrame samples,
    int tau,
    int maxTau,
  ) {
    final x0 = math.max(tau - 1, 0);
    final x2 = math.min(tau + 1, samples.length - 1);
    if (x0 == tau || x2 == tau) return tau.toDouble();

    final s0 = samples[x0];
    final s1 = samples[tau];
    final s2 = samples[x2];
    final offset = quadraticExtremum(s0, s1, s2);
    if (offset.isNaN) return tau.toDouble();
    return tau + offset.clamp(-0.5, 0.5);
  }

  static double quadraticExtremum(double fm1, double f0, double f1) {
    // 2nd difference ≈ f''(0)
    final delta2 = fm1 - 2.0 * f0 + f1;
    if (delta2.abs() < eps) return double.nan;
    return (fm1 - f1) / (2.0 * delta2);
  }

  static double centsBetween(double f1Hz, double f2Hz) {
    assert(f1Hz > 0);
    assert(f2Hz > 0);
    return 1200 * (math.log(f1Hz / f2Hz) / math.ln2);
  }
}

extension _AudioFrameExt on AudioFrame {
  bool get isValid => every((value) => value.isFinite);
  bool get isInvalid => !isValid;
}

/// デシベル単位に変換
double _convertDecibels(double value) {
  final result = 20 * math.log(value) / math.ln10;
  return result;
}
