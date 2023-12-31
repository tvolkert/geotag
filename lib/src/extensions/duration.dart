extension DurationExtensions on Duration {
  String toSecondsPrecision() {
    int microseconds = inMicroseconds;
    String sign = '';
    final bool negative = microseconds < 0;

    int hours = microseconds ~/ Duration.microsecondsPerHour;
    microseconds = microseconds.remainder(Duration.microsecondsPerHour);

    // Correcting for being negative after first division, instead of before,
    // to avoid negating min-int, -(2^31-1), of a native int64.
    if (negative) {
      hours = 0 - hours; // Not using `-hours` to avoid creating -0.0 on web.
      microseconds = 0 - microseconds;
      sign = '-';
    }

    final int minutes = microseconds ~/ Duration.microsecondsPerMinute;
    microseconds = microseconds.remainder(Duration.microsecondsPerMinute);

    final String minutesPadding = minutes < 10 ? '0' : '';

    final int seconds = microseconds ~/ Duration.microsecondsPerSecond;
    microseconds = microseconds.remainder(Duration.microsecondsPerSecond);

    String secondsPadding = seconds < 10 ? '0' : '';

    final StringBuffer buf = StringBuffer()..write(sign);
    if (hours > 0) {
      buf.write('$hours:');
    }
    buf
        ..write('$minutesPadding$minutes:')
        ..write('$secondsPadding$seconds')
        ;
    return buf.toString();
  }
}
