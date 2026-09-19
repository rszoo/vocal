import 'package:flutter/foundation.dart';

import '../../feature/monophony.dart';

/// マイク入力音声（ボーカル・発声） YIN ピッチ検出器
abstract class YinV0 {
  YinV0({
    required this.sampleRate,
    required this.frameSize,
    required this.minF0,
    required this.maxF0,
    required this.minConfidence,
  }) : assert(sampleRate > 0),
       assert(frameSize > 0),
       assert(minF0 > 0),
       assert(minF0 < maxF0),
       minTau = (sampleRate / maxF0).floor(),
       maxTau = (sampleRate / minF0).ceil(),
       assert(minConfidence >= 0 && minConfidence <= 1) {
    assert(minTau >= 2);
    assert(minTau < maxTau);

    debugPrint(
      '{'
      ' minTau : $minTau,'
      ' maxTau : $maxTau,'
      '}',
    );

    _cmnd = Float32List(maxTau + 1);
  }

  final int sampleRate;
  final int frameSize;
  final int minF0;
  final int maxF0;
  final int minTau;
  final int maxTau;

  /// ピッチ候補を採用するための最低信頼度
  final double minConfidence;

  // 作業用バッファ
  @protected
  Float32List get cmnd => _cmnd;
  late final Float32List _cmnd;

  static const eps = 1e-10;

  /// フレームから周波数 (Hz) を返す
  F0? detect(final Float32List samples) {
    assert(samples.isNotEmpty, 'samples.isNotEmpty [ ${samples.isNotEmpty} ]');
    assert(samples.length == frameSize);

    // 累積平均正規化差分関数
    _cmndFn(samples);

    final tau = findTau(_cmnd);
    if (tau == null) return null;

    final refinedTau = interpolateTau(_cmnd, tau);
    if (!refinedTau.isFinite || refinedTau <= 0.0) return null;

    // 周波数・信頼度の算出
    final freq = sampleRate / refinedTau;
    if (freq < minF0 || freq > maxF0) return null;

    final confidence = (1.0 - _cmnd[tau]).clamp(0.0, 1.0);
    if (confidence < minConfidence) return null;

    return freq;
  }

  /// Difference Function d(τ)
  /// Cumulative Mean Normalized Difference Function d'(τ)
  void _cmndFn(final Float32List samples) {
    final half = samples.length ~/ 2;
    assert(half > maxTau);

    var runningSum = 0.0;
    _cmnd[0] = 1.0;
    for (var tau = 1; tau <= maxTau; tau++) {
      var sum = 0.0;
      for (var i = 0; i < half; i++) {
        final delta = samples[i] - samples[i + tau];
        sum += delta * delta;
      }

      runningSum += sum;
      _cmnd[tau] = runningSum < eps ? 1.0 : (sum * tau) / runningSum;
    }
  }

  @protected
  int? findTau(final Float32List cmnd);

  @protected
  double interpolateTau(final Float32List cmnd, final int tau);
}
