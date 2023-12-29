extension DateTimeExtension on DateTime {
  String toVideoString() {
    // 2010-01-01 00:00:00
    final String year = this.year.toString().padLeft(4, '0');
    final String month = this.month.toString().padLeft(2, '0');
    final String day = this.day.toString().padLeft(2, '0');
    final String hour = this.hour.toString().padLeft(2, '0');
    final String minute = this.minute.toString().padLeft(2, '0');
    final String second = this.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
