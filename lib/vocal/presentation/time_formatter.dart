class TimeFormatter {
  const TimeFormatter();

  String format(double seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
    final minutes = total ~/ 60;
    final remainder = total % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
