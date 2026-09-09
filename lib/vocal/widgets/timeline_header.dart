import 'package:flutter/material.dart';

import '../presentation/time_formatter.dart';

class TimelineHeader extends StatelessWidget {
  const TimelineHeader({
    super.key,
    required this.currentTime,
    required this.duration,
  });

  final double currentTime;
  final double duration;
  static const formatter = TimeFormatter();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          const SizedBox(width: 64),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TimeText(formatter.format(currentTime)),
                  _TimeText(formatter.format(duration)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeText extends StatelessWidget {
  const _TimeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
