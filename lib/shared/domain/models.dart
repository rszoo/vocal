// ./lib/shared/domain/models.dart

import 'package:collection/collection.dart';

import '../../feature/monophony.dart';

/// 参照側のピッチ区間
extension type PitchSegment._(({double time, T0 period, F0 freq}) _) {
  const PitchSegment({
    required double time,
    required T0 period,
    required F0 freq,
  }) : _ = (time: time, period: period, freq: freq);

  /// 開始位置（秒）
  double get time => _.time;

  /// 時間幅（秒）
  T0 get period => _.period;

  /// 基本周波数（Hz）
  F0 get freq => _.freq;

  double get endTime => time + period;

  /// MIDI ノート番号への変換
  Midi get midi => convertF0ToMidi(freq);

  factory PitchSegment.fromJson(Map<String, dynamic> json) {
    return PitchSegment(
      time: (json['time_s'] as num).toDouble(),
      period: (json['t0_s'] as num).toDouble(),
      freq: (json['f0_hz'] as num).toDouble(),
    );
  }
}

extension PitchSegmentListExt on List<PitchSegment> {
  double get maxEndTime {
    var e = maxBy(this, (e) => e.endTime);
    return e != null ? e.endTime : 0;
  }
}
