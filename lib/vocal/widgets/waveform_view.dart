import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/models/timeline_frame.dart';
import '../presentation/timeline_calculator.dart';

class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.frame,
    required this.calculator,
  });

  final TimelineFrame frame;
  final TimelineCalculator calculator;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      isComplex: true,
      willChange: true,
      painter: _WaveformPainter(frame: frame, calculator: calculator),
      child: const SizedBox.expand(),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.frame, required this.calculator});

  final TimelineFrame frame;
  final TimelineCalculator calculator;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B1018),
    );

    final baseline = Paint()
      ..color = const Color(0xFF33465D)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(frame.pianoWidth, size.height / 2),
      Offset(size.width, size.height / 2),
      baseline,
    );

    _drawEnvelope(
      canvas,
      size,
      frame.referenceWaveform,
      const Color(0xFF6CA6FF),
      0.36,
    );
    _drawEnvelope(
      canvas,
      size,
      frame.liveWaveform,
      const Color(0xFFFFC857),
      0.46,
    );
    _drawPlayhead(canvas, size);
  }

  void _drawEnvelope(
    Canvas canvas,
    Size size,
    List<WaveformSample> samples,
    Color color,
    double scale,
  ) {
    if (samples.isEmpty) return;

    final upper = Path();
    final lower = Path();
    var started = false;

    for (final sample in samples) {
      final x = calculator.timeToX(frame, sample.timeSeconds);
      if (x < frame.pianoWidth - 2 || x > size.width + 2) continue;
      final amplitude = sample.amplitude * size.height * scale;
      final center = size.height / 2;
      final top = center - amplitude;
      final bottom = center + amplitude;

      if (!started) {
        upper.moveTo(x, top);
        lower.moveTo(x, bottom);
        started = true;
      } else {
        upper.lineTo(x, top);
        lower.lineTo(x, bottom);
      }
    }

    if (!started) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(upper, paint);
    canvas.drawPath(lower, paint);
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

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
