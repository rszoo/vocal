import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../feature/monophony.dart';
import '../../../shared/domain/models.dart';
import '../../domain/models.dart';
import '../../fns.dart';
import '../classes.dart';

/// ピアノロール全体を構築するウィジェット。
/// 3つの CustomPaint (Playback, LiveData, Overlay) を重ね合わせて描画する。
class PianoRoll extends StatelessWidget {
  const PianoRoll({
    super.key,
    required this.pitches,
    required this.currentTime,
    required this.liveSamples,
    required this.duration,
    required this.rangeMode,
    required this.startTime,
    this.colors,
  });

  final List<PitchSegment> pitches;
  final double currentTime;
  final List<LivePitchSample> liveSamples;
  final double duration;

  final PianoRangeMode rangeMode;

  final double startTime;

  final PianoRollColors? colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColors =
        colors ?? PianoRollColors(colorScheme: theme.colorScheme);

    final isSingleOctave = rangeMode == PianoRangeMode.tone;
    final lowMidi = isSingleOctave ? 0 : 36;
    final highMidi = isSingleOctave ? 11 : 96;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // 【背景と録音済みノートのレイヤー】
          // 変更頻度が低い背景グリッドや入力済みの音符を描画
          CustomPaint(
            painter: _PlaybackPainter(
              pitches: pitches,
              startTime: startTime,
              duration: duration,
              lowMidi: lowMidi,
              highMidi: highMidi,
              colors: effectiveColors,
              labelStyle: theme.textTheme.labelSmall,
              isSingleOctave: isSingleOctave,
            ),
            child: const SizedBox.expand(),
          ),
          // 【リアルタイムデータのレイヤー】
          // 現在入力中の音声ピッチデータなどを描画
          CustomPaint(
            painter: _LiveDataPainter(
              liveSamples: liveSamples,
              startTime: startTime,
              duration: duration,
              lowMidi: lowMidi,
              highMidi: highMidi,
              colors: effectiveColors,
              labelStyle: theme.textTheme.labelSmall,
              isSingleOctave: isSingleOctave,
            ),
            child: const SizedBox.expand(),
          ),
          // 【オーバーレイ（前面）レイヤー】
          // 常に動く再生ヘッド（縦線）や、左側に固定される鍵盤を描画
          CustomPaint(
            painter: _OverlayPainter(
              currentTime: currentTime,
              startTime: startTime,
              duration: duration,
              lowMidi: lowMidi,
              highMidi: highMidi,
              colors: effectiveColors,
              labelStyle: theme.textTheme.labelSmall,
              isSingleOctave: isSingleOctave,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

const _beatsPerMeasure = beatsPerMeasure;

const _rollOffset = Offset(pianoRollKeyboardWidth, pianoRollRulerHeight);

/// MIDI ノートが黒鍵かどうかを判定
bool _isBlackKey(Midi midi) => isAccidentalNote(midi);

/// 全ての Painter の基底クラス。
/// 座標変換（時間->X, ピッチ->Y）などの共通ロジックを提供する。
abstract class _PianoRollPainter extends CustomPainter {
  _PianoRollPainter({
    required this.pitches,
    required this.liveSamples,
    required this.currentTime,
    required this.startTime,
    required this.duration,
    required this.lowMidi,
    required this.highMidi,
    required this.colors,
    required this.labelStyle,
    required this.isSingleOctave,
  });

  final List<PitchSegment> pitches;
  final List<LivePitchSample> liveSamples;
  final double currentTime;
  final double startTime;
  final double duration;
  final Midi lowMidi;
  final Midi highMidi;
  final PianoRollColors colors;
  final TextStyle? labelStyle;
  final bool isSingleOctave;

  /// 表示する総半音数
  int get semitones => highMidi - lowMidi + 1;

  /// 1つの音の高さ（行の高さ）を計算
  double rowHeight(double h) => math.max(1, (h - _rollOffset.dy) / semitones);

  /// 時間（秒）から画面上の X 座標を計算する
  double timeToX(double time, double width) {
    return ((time - startTime) / duration).clamp(-1.0, 2.0) *
            (width - _rollOffset.dx) +
        _rollOffset.dx;
  }

  /// MIDI ノート番号から画面上の Y 座標の中心位置を計算する
  double midiToY(Midi midi, double height) {
    if (isSingleOctave) {
      final pitchClass = midi.floor() % 12;
      final pitchRow = 11 - pitchClass; // 画面上部が高い音
      return _rollOffset.dy + (pitchRow + .5) * rowHeight(height);
    } else {
      final pitchRow = highMidi - midi;
      return _rollOffset.dy + (pitchRow + .5) * rowHeight(height);
    }
  }

  /// 音域によってノートの太さ（高さ）を調整する
  double noteThicknessRatio(Midi midi) {
    if (!isSingleOctave) return 0.58;

    final octave = (midi.floor() ~/ 12) - 1;
    final clampedOctave = octave.clamp(2, 6);
    final normalized = (6 - clampedOctave) / 4.0;

    return 0.25 + (normalized * 0.60);
  }

  /// ノートの色を計算（少しグラデーションのような効果を出す）
  Color _noteColor(PitchSegment note) {
    final t = ((note.midi.floor() % 3) / 2 * .18).clamp(0.0, 1.0);
    return Color.lerp(colors.primaryNote, colors.secondaryNote, t) ??
        colors.primaryNote;
  }
}

/// 【背景と録音済みノートを描画するクラス】
final class _PlaybackPainter extends _PianoRollPainter {
  _PlaybackPainter({
    required super.pitches,
    super.liveSamples = const [],
    super.currentTime = 0,
    required super.startTime,
    required super.duration,
    required super.lowMidi,
    required super.highMidi,
    required super.colors,
    required super.labelStyle,
    required super.isSingleOctave,
  }) : _beatSeconds = 60 / tempoBpm;

  final double _beatSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final rollWidth = size.width - _rollOffset.dx;

    // 全体の背景を塗りつぶす
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()..color = colors.background,
    );

    canvas.save();
    // 描画領域をキーボードとルーラー以外に制限（はみ出し防止）
    canvas.clipRect(
      Rect.fromLTWH(
        _rollOffset.dx,
        _rollOffset.dy,
        rollWidth,
        size.height - _rollOffset.dy,
      ),
    );

    final row = rowHeight(size.height);

    // 1. 横方向の背景ストライプを描画（黒鍵の位置に色をつける）
    for (var i = 0; i < semitones; i++) {
      final midi = isSingleOctave ? (11 - i) : (highMidi - i);
      if (_isBlackKey(midi)) {
        canvas.drawRect(
          Rect.fromLTWH(
            _rollOffset.dx,
            _rollOffset.dy + i * row,
            rollWidth,
            row,
          ),
          Paint()..color = colors.alternateKey,
        );
      }
    }

    // 2. 横方向のグリッド線を描画（Cの音は太くする）
    for (var i = 0; i < semitones; i++) {
      final midi = isSingleOctave ? (11 - i) : (highMidi - i);
      final y = _rollOffset.dy + i * row;
      final isC = midi % 12 == 0;
      canvas.drawLine(
        Offset(_rollOffset.dx, y),
        Offset(size.width, y),
        Paint()
          ..color = isC ? colors.strongGrid : colors.grid
          ..strokeWidth = isC ? 1.1 : .55,
      );
    }

    final firstBeat = (startTime / _beatSeconds).floor() - 1;
    final lastBeat = ((startTime + duration) / _beatSeconds).ceil() + 1;

    // 3. 縦方向のグリッド線を描画（小節の頭は太くする）
    for (var beat = firstBeat; beat <= lastBeat; beat++) {
      final time = beat * _beatSeconds;
      final x = timeToX(time, size.width);
      final isBar = beat % _beatsPerMeasure == 0;

      canvas.drawLine(
        Offset(x, _rollOffset.dy),
        Offset(x, size.height),
        Paint()
          ..color = isBar ? colors.strongGrid : colors.grid
          ..strokeWidth = isBar ? 1.2 : .65,
      );
    }

    // 4. 入力済みのノート（音符）を描画
    for (final note in pitches) {
      // 画面外のノートは描画しない
      if (note.endTime < startTime || note.time > startTime + duration) {
        continue;
      }
      if (!isSingleOctave) {
        if (note.midi < lowMidi - .49 || note.midi > highMidi + .49) {
          continue;
        }
      }

      final x1 = timeToX(note.time, size.width);
      final x2 = timeToX(note.endTime, size.width);
      final y = midiToY(note.midi, size.height);

      final thicknessRatio = noteThicknessRatio(note.midi);
      final noteHeight = row * thicknessRatio;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset((x1 + x2) / 2, y),
            width: math.max(2, x2 - x1),
            height: noteHeight,
          ),
          Radius.circular(math.max(2, noteHeight * .25)),
        ),
        Paint()..color = _noteColor(note),
      );
    }

    canvas.restore();

    // 5. ルーラー（ヘッダー）の小節番号を描画
    _drawHeader(canvas, size);
  }

  /// 上部のルーラーに小節番号を描画する
  void _drawHeader(Canvas canvas, Size size) {
    final style =
        labelStyle?.copyWith(color: colors.label) ??
        TextStyle(color: colors.label, fontSize: 11);

    final painter = TextPainter(textDirection: TextDirection.ltr);

    // 1小節あたりの秒数を計算
    final measureSeconds = _beatSeconds * _beatsPerMeasure;

    // 小節単位で表示範囲の最初と最後のインデックスを計算
    final firstMeasureIndex = (startTime / measureSeconds).floor() - 1;
    final lastMeasureIndex =
        ((startTime + duration) / measureSeconds).ceil() + 1;

    // 拍ごとではなく、小節ごと（i）にループを回す
    for (var i = firstMeasureIndex; i <= lastMeasureIndex; i++) {
      final time = i * measureSeconds;
      if (time < 0) continue;

      final x = timeToX(time, size.width);
      if (x < _rollOffset.dx || x > size.width) continue;

      // 小節番号 (インデックスは0始まりなので+1)
      final measure = i + 1;

      painter.text = TextSpan(text: '$measure', style: style);
      painter.layout();
      painter.paint(canvas, Offset(x + 4, 7));
    }
  }

  @override
  bool shouldRepaint(covariant _PlaybackPainter oldDelegate) {
    // 表示範囲やノートが変更された場合のみ再描画
    return oldDelegate.startTime != startTime ||
        oldDelegate.duration != duration ||
        oldDelegate.pitches != pitches ||
        oldDelegate.lowMidi != lowMidi ||
        oldDelegate.highMidi != highMidi ||
        oldDelegate.isSingleOctave != isSingleOctave;
  }
}

/// 【リアルタイムの入力データを描画するクラス】
final class _LiveDataPainter extends _PianoRollPainter {
  _LiveDataPainter({
    super.pitches = const [],
    required super.liveSamples,
    super.currentTime = 0,
    required super.startTime,
    required super.duration,
    required super.lowMidi,
    required super.highMidi,
    required super.colors,
    super.labelStyle,
    required super.isSingleOctave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (liveSamples.isEmpty) return;

    canvas.save();
    // 描画領域をキーボードとルーラー以外に制限
    canvas.clipRect(
      Rect.fromLTWH(
        _rollOffset.dx,
        _rollOffset.dy,
        size.width - _rollOffset.dx,
        size.height - _rollOffset.dy,
      ),
    );

    // 線を描画するための Paint 設定
    final linePaint = Paint()
      ..color = colors
          .live // 線の基本色
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var hasPoint = false;
    var previousX = double.nan;

    // リアルタイムサンプルの描画
    for (final sample in liveSamples) {
      if (sample.time < startTime - .8 ||
          sample.time > startTime + duration + .8) {
        continue;
      }
      if (!isSingleOctave) {
        if (sample.midi < lowMidi - .49 || sample.midi > highMidi + .49) {
          continue;
        }
      }

      final x = timeToX(sample.time, size.width);
      final y = midiToY(sample.midi, size.height);

      // 1. 線をつなぐ処理
      // 前の点からX座標が一定以上離れている場合（音が途切れた場合など）は新しくPathを始める
      if (!hasPoint || (x - previousX).abs() > size.width * 0.35) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // 2. 点を描画する
      // ピッチが合っているか（match）でドットの色を切り替える
      final pointPaint = Paint()
        ..color = sample.match ? colors.match : colors.live;
      canvas.drawCircle(Offset(x, y), 2.4, pointPaint);

      hasPoint = true;
      previousX = x;
    }

    // 3. 構築した線を最後にまとめて描画
    if (hasPoint) {
      canvas.drawPath(path, linePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiveDataPainter oldDelegate) {
    return oldDelegate.liveSamples != liveSamples ||
        oldDelegate.startTime != startTime ||
        oldDelegate.duration != duration ||
        oldDelegate.lowMidi != lowMidi ||
        oldDelegate.highMidi != highMidi ||
        oldDelegate.isSingleOctave != isSingleOctave;
  }
}

/// 【再生ヘッドと左側の鍵盤を描画するクラス】
final class _OverlayPainter extends _PianoRollPainter {
  _OverlayPainter({
    super.pitches = const [],
    super.liveSamples = const [],
    required super.currentTime,
    required super.startTime,
    required super.duration,
    required super.lowMidi,
    required super.highMidi,
    required super.colors,
    required super.labelStyle,
    required super.isSingleOctave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final row = rowHeight(size.height);

    canvas.save();
    // 再生ヘッドの描画領域をキーボードとルーラー以外に制限
    canvas.clipRect(
      Rect.fromLTWH(
        _rollOffset.dx,
        _rollOffset.dy,
        size.width - _rollOffset.dx,
        size.height - _rollOffset.dy,
      ),
    );

    // 1. 再生ヘッド（現在の再生位置を示す縦線）の描画
    final headX = timeToX(currentTime, size.width);
    canvas.drawLine(
      Offset(headX, 0),
      Offset(headX, size.height),
      Paint()
        ..color = colors.playhead
        ..strokeWidth = 2,
    );
    canvas.restore();

    // 2. 左側の鍵盤の描画
    _drawKeyboard(canvas, size, row);
  }

  /// 左側のピアノ鍵盤を描画する
  void _drawKeyboard(Canvas canvas, Size size, double row) {
    // 鍵盤エリアの背景
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        _rollOffset.dy,
        _rollOffset.dx,
        size.height - _rollOffset.dy,
      ),
      Paint()..color = colors.keyboard,
    );

    for (var i = 0; i < semitones; i++) {
      final midi = isSingleOctave ? (11 - i) : (highMidi - i);
      final y = _rollOffset.dy + i * row;

      if (_isBlackKey(midi)) {
        // 黒鍵を描画（少し短くする）
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, y - row * .28, _rollOffset.dx * .66, row * .56),
            const Radius.circular(3),
          ),
          Paint()..color = colors.blackKey,
        );
      } else {
        // 白鍵の間の線を描画
        canvas.drawLine(
          Offset(0, y),
          Offset(_rollOffset.dx, y),
          Paint()
            ..color = colors.keyboardLine
            ..strokeWidth = .55,
        );
      }

      // C（ド）の鍵盤にノート名（例: C4）を描画
      if (midi % 12 == 0) {
        final label = isSingleOctave ? 'C' : 'C${(midi ~/ 12) - 1}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style:
                labelStyle?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ) ??
                TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            _rollOffset.dx - textPainter.width - 6,
            y + (row - textPainter.height) / 2,
          ),
        );
      }
    }

    // 鍵盤と右側のエリアを区切る縦線
    canvas.drawLine(
      Offset(_rollOffset.dx, _rollOffset.dy),
      Offset(_rollOffset.dx, size.height),
      Paint()..color = colors.keyboardLine,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    // 再生位置が更新された場合などに再描画（最も頻繁に呼ばれる）
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.isSingleOctave != isSingleOctave;
  }
}
