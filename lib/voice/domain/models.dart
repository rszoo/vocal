// ./lib/voice/domain/models.dart

import 'package:flutter/foundation.dart';

import '../../feature/monophony.dart';

@immutable
class PitchData {
  const PitchData({
    this.pitch = 0.0,
    this.note = '',
    this.midiNote = 0,
    this.cents = 0.0,
  });

  /// 基本周波数 (F0)
  final F0 pitch;
  final String note;
  final Midi midiNote;
  final double cents;

  static const double tolerance = 5.0;

  bool get isInTune => cents.abs() < tolerance;

  bool get isSharp => cents >= tolerance;

  bool get isFlat => cents <= -tolerance;

  String get tuningText {
    if (isInTune) return 'ぴったり';
    if (isSharp) return '${cents.toStringAsFixed(1)} cent 高い';
    if (isFlat) return '${cents.abs().toStringAsFixed(1)} cent 低い';
    return '解析不能';
  }

  @protected
  String toStringWithMember() =>
      'pitch: ${pitch.toStringAsFixed(1)}Hz, '
      'note: $note, '
      'midi: $midiNote, '
      'cents: ${cents.toStringAsFixed(1)}';

  @override
  String toString() => 'PitchData( ${toStringWithMember()} )';
}

/// 採点システム向けに出力される音声データ
@immutable
class VoiceData extends PitchData {
  const VoiceData({
    required this.isVoice,
    super.pitch = 0.0,
    super.note = '',
    super.midiNote = 0,
    super.cents = 0.0,
    required this.level,
  });

  final bool isVoice;

  final double level;

  /// ドレミ・MIDI変換ロジック
  factory VoiceData.from({
    required bool isVoice,
    required F0 pitch,
    required double level,
  }) {
    if (pitch <= 0) return VoiceData(isVoice: false, level: level);

    // A4 = 440Hz
    final midiFloat = convertF0ToMidiFloat(pitch);

    final midi = midiFloat.round();

    final note = [
      'ド',
      'ド♯',
      'レ',
      'レ♯',
      'ミ',
      'ファ',
      'ファ♯',
      'ソ',
      'ソ♯',
      'ラ',
      'ラ♯',
      'シ',
    ][((midi % 12) + 12) % 12];

    final cents = (midiFloat - midi) * 100;

    return VoiceData(
      isVoice: true,
      pitch: pitch,
      note: note,
      midiNote: midi,
      cents: cents,
      level: level,
    );
  }

  @override
  @protected
  String toStringWithMember() =>
      'isVoice: $isVoice, '
      '${super.toStringWithMember()}, '
      'level: ${level.toStringAsFixed(1)}';

  @override
  String toString() => 'VoiceData( ${toStringWithMember()} )';
}
