import 'package:flutter/material.dart';

class TimelineLegend extends StatelessWidget {
  const TimelineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _LegendItem(color: Color(0xFF6CA6FF), label: '参照'),
        _LegendItem(color: Color(0xFF62E6A7), label: '一致した参照音'),
        _LegendItem(color: Color(0xFFFFC857), label: 'マイク音'),
        _LegendItem(color: Color(0xFFFF5B5B), label: '再生位置'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}
