import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/models/timeline_frame.dart';
import '../presentation/timeline_calculator.dart';

class PianoRoll extends StatelessWidget {
  const PianoRoll({
    super.key,
    required this.frame,
    required this.calculator,
    required this.onSeek,
  });

  final TimelineFrame frame;
  final TimelineCalculator calculator;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        final seconds = calculator.xToTime(frame, details.localPosition.dx);
        onSeek(seconds.clamp(frame.visibleStart, frame.visibleEnd).toDouble());
      },
      child: CustomPaint(
        painter: _PianoRollPainter(frame: frame, calculator: calculator),
      ),
    );
  }
}

class _PianoRollPainter extends CustomPainter {
  const _PianoRollPainter({required this.frame, required this.calculator});

  final TimelineFrame frame;
  final TimelineCalculator calculator;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF111318);
    canvas.drawRect(Offset.zero & size, background);

    _drawGrid(canvas, size);
    _drawKeyboard(canvas, size);
    _drawNotes(canvas, size);
    _drawLivePitches(canvas, size);
    _drawPlayhead(canvas, size);
  }

  int get _bottomMidi =>
      frame.displayMode == PianoRollDisplayMode.singleOctave ? 60 : 36;

  int get _topMidi =>
      frame.displayMode == PianoRollDisplayMode.singleOctave ? 72 : 96;

  int get _rowCount => _topMidi - _bottomMidi;

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2B2F36)
      ..strokeWidth = 0.5;

    final strongGridPaint = Paint()
      ..color = const Color(0xFF424750)
      ..strokeWidth = 0.8;

    final pixelsPerSecond =
        frame.contentWidth / (frame.visibleEnd - frame.visibleStart);
    final firstSecond = frame.visibleStart.floor();

    for (
      var second = firstSecond;
      second <= frame.visibleEnd.ceil();
      second++
    ) {
      final x =
          frame.pianoWidth + (second - frame.visibleStart) * pixelsPerSecond;
      final paint = second % 4 == 0 ? strongGridPaint : gridPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var row = 0; row <= _rowCount; row++) {
      final y = row / _rowCount * size.height;
      final midi = _topMidi - row;
      final paint = midi % 12 == 0 ? strongGridPaint : gridPaint;
      canvas.drawLine(
        Offset(frame.pianoWidth, y),
        Offset(size.width, y),
        paint,
      );
    }

    canvas.drawLine(
      Offset(frame.pianoWidth, 0),
      Offset(frame.pianoWidth, size.height),
      strongGridPaint,
    );
  }

  void _drawKeyboard(Canvas canvas, Size size) {
    final whiteKey = Paint()..color = const Color(0xFFE8E8E8);
    final blackKey = Paint()..color = const Color(0xFF20242A);
    final border = Paint()
      ..color = const Color(0xFF70757D)
      ..strokeWidth = 0.5;

    final keyHeight = size.height / _rowCount;

    for (var i = 0; i < _rowCount; i++) {
      final y = i * keyHeight;
      final midi = _topMidi - 1 - i;
      final isBlack = _isBlackKey(midi);
      canvas.drawRect(
        Rect.fromLTWH(0, y, frame.pianoWidth, keyHeight),
        isBlack ? blackKey : whiteKey,
      );
      canvas.drawLine(
        Offset(0, y + keyHeight),
        Offset(frame.pianoWidth, y + keyHeight),
        border,
      );

      if (midi % 12 == 0) {
        final octave = midi ~/ 12 - 1;
        final text = TextPainter(
          text: TextSpan(
            text: 'C$octave',
            style: TextStyle(
              color: isBlack ? Colors.white : Colors.black,
              fontSize: 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(4, y + 2));
      }
    }

    final topLabelMidi = _topMidi;
    final topOctave = topLabelMidi ~/ 12 - 1;
    final topLabel = 'C$topOctave';
    final topText = TextPainter(
      text: TextSpan(
        text: topLabel,
        style: const TextStyle(color: Colors.white, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    topText.paint(canvas, const Offset(4, 2));
  }

  void _drawNotes(Canvas canvas, Size size) {
    for (var i = 0; i < frame.referenceEvents.length; i++) {
      final event = frame.referenceEvents[i];
      if (event.endSeconds < frame.visibleStart ||
          event.startSeconds > frame.visibleEnd) {
        continue;
      }

      final x1 = calculator.timeToX(frame, event.startSeconds);
      final x2 = calculator.timeToX(frame, event.endSeconds);
      final y = calculator.frequencyToY(frame, event.f0Hz, size.height);
      if (y < -8 || y > size.height + 8) continue;
      final matched = frame.matchingReferenceIndices.contains(i);

      final paint = Paint()
        ..color = matched ? const Color(0xFF62E6A7) : const Color(0xFF6CA6FF);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x1,
            y - 4,
            x2.clamp(x1 + 2, size.width).toDouble(),
            y + 4,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  void _drawLivePitches(Canvas canvas, Size size) {
    if (frame.livePitches.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFFFFC857)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = const Color(0xFFFFC857);

    final path = Path();
    var hasPoint = false;
    var previousX = double.nan;
    var previousY = double.nan;

    for (final pitch in frame.livePitches) {
      if (pitch.timeSeconds < frame.visibleStart ||
          pitch.timeSeconds > frame.visibleEnd) {
        continue;
      }
      final x = calculator.timeToX(frame, pitch.timeSeconds);
      final y = calculator.frequencyToY(frame, pitch.frequencyHz, size.height);
      if (y < -4 || y > size.height + 4) continue;

      if (!hasPoint || (x - previousX).abs() > size.width * 0.35) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 2.4, pointPaint);
      hasPoint = true;
      previousX = x;
      previousY = y;
    }

    if (hasPoint) canvas.drawPath(path, linePaint);
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5B5B)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(frame.playheadX, 0),
      Offset(frame.playheadX, size.height),
      paint,
    );
  }

  bool _isBlackKey(int midi) {
    switch (midi % 12) {
      case 1:
      case 3:
      case 6:
      case 8:
      case 10:
        return true;
      default:
        return false;
    }
  }

  @override
  bool shouldRepaint(covariant _PianoRollPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
