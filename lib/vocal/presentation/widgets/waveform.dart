import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/domain/models.dart';
import '../../domain/models.dart';
import '../../fns.dart';
import '../classes.dart';

class WaveformPanel extends StatelessWidget {
  const WaveformPanel({
    super.key,
    required this.currentTime,
    required this.startTime,
    required this.duration,
    required this.pitches,
    required this.liveSamples,
    this.timelineLeadingInset = pianoRollKeyboardWidth,
    this.colors,
  });

  final double currentTime;
  final double startTime;
  final double duration;
  final List<PitchSegment> pitches;
  final List<LivePitchSample> liveSamples;
  final double timelineLeadingInset;
  final WaveformColors? colors;

  @override
  Widget build(BuildContext context) {
    final effectiveColors =
        colors ?? WaveformColors(colorScheme: Theme.of(context).colorScheme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _WaveformPainter(
          currentTime: currentTime,
          startTime: startTime,
          duration: duration,
          pitches: pitches,
          liveSamples: liveSamples,
          colors: effectiveColors,
          timelineLeadingInset: timelineLeadingInset,
        ),
        child: const SizedBox(width: double.infinity, height: 92),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.currentTime,
    required this.startTime,
    required this.duration,
    required this.pitches,
    required this.liveSamples,
    required this.colors,
    required this.timelineLeadingInset,
  });

  final double currentTime;
  final double startTime;
  final double duration;
  final List<PitchSegment> pitches;
  final List<LivePitchSample> liveSamples;
  final WaveformColors colors;
  final double timelineLeadingInset;

  double _timeToX(double time, double width) {
    final timelineWidth = math.max(1.0, width - timelineLeadingInset);
    return timelineLeadingInset +
        ((time - startTime) / duration).clamp(-1.0, 2.0) * timelineWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);

    final mid = size.height / 2;

    final timelineWidth = math.max(1.0, size.width - timelineLeadingInset);
    for (var i = 0; i <= 8; i++) {
      final x = timelineLeadingInset + timelineWidth * i / 8;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = colors.grid
          ..strokeWidth = i.isEven ? 1 : .5,
      );
    }

    final referencePath = Path();
    const samples = 360;

    for (var i = 0; i < samples; i++) {
      final time = startTime + duration * i / (samples - 1);
      final x = _timeToX(time, size.width);
      final active = _segmentAt(time);

      final envelope = active == null
          ? .08
          : .14 +
                .20 *
                    (0.5 +
                        0.5 *
                            math.sin(active.freq * .004 * time + active.midi));

      final y = mid - envelope * size.height * .55;
      if (i == 0) {
        referencePath.moveTo(x, y);
      } else {
        referencePath.lineTo(x, y);
      }
    }

    canvas.drawPath(
      referencePath,
      Paint()
        ..color = colors.reference
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final recent = liveSamples.length > 18
        ? liveSamples.sublist(liveSamples.length - 18)
        : liveSamples;

    for (final sample in recent) {
      if (sample.waveform.isEmpty) continue;

      final x = _timeToX(sample.time, size.width);
      if (x < 0 || x > size.width) continue;

      final maxPoints = math.min(90, sample.waveform.length);
      final path = Path();

      for (var i = 0; i < maxPoints; i++) {
        final index = math.max(
          0,
          math.min(
            sample.waveform.length - 1,
            sample.waveform.length - maxPoints + i,
          ),
        );
        final amp = sample.waveform[index].clamp(-1.0, 1.0);
        final y = mid + amp * size.height * .36;
        final px = x - 18 + 36 * i / math.max(1, maxPoints - 1);

        if (i == 0) {
          path.moveTo(px, y);
        } else {
          path.lineTo(px, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = sample.match ? colors.match : colors.mic
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05,
      );
    }

    final playheadX = _timeToX(currentTime, size.width);

    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      Paint()
        ..color = colors.playhead
        ..strokeWidth = 1.8,
    );
  }

  PitchSegment? _segmentAt(double time) {
    for (final p in pitches) {
      if (time >= p.time && time <= p.endTime) {
        return p;
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.startTime != startTime ||
        oldDelegate.liveSamples != liveSamples ||
        oldDelegate.pitches != pitches;
  }
}
