import 'package:image/image.dart';

extension ExifDateTime on DateTime {
  static DateTime? original(IfdDirectory ifd) => _extract(ifd, _dateTimeOriginalTagName);
  static DateTime? digitized(IfdDirectory ifd) => _extract(ifd, _dateTimeDigitizedTagName);

  static const String _dateTimeOriginalTagName = 'DateTimeOriginal';
  static const String _dateTimeDigitizedTagName = 'DateTimeDigitized';

  static const String _format = r'([0-9]{4}):([0-9]{2}):([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})';

  static DateTime? _extract(IfdDirectory ifd, String tagName) {
    final Map<int, IfdValue> data = ifd.data;
    final IfdValue? dateTime = data[exifTagNameToID[tagName]];
    if (dateTime == null) {
      return null;
    }
    assert(dateTime.type == IfdValueType.ascii);
    final RegExp re = RegExp(_format);
    final RegExpMatch? match = re.firstMatch(dateTime.toString());
    assert(match != null);
    final int year = int.parse(match!.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final int hours = int.parse(match.group(4)!);
    final int minutes = int.parse(match.group(5)!);
    final int seconds = int.parse(match.group(6)!);
    return DateTime(year, month, day, hours, minutes, seconds);
  }

  Map<int, IfdValue> get exifDataAsOriginal => _getExifData(_dateTimeOriginalTagName);

  Map<int, IfdValue> get exifDataAsDigitized => _getExifData(_dateTimeDigitizedTagName);

  Map<int, IfdValue> _getExifData(String tagName) {
    final String year = this.year.toString().padLeft(4, '0');
    final String month = this.month.toString().padLeft(2, '0');
    final String day = this.day.toString().padLeft(2, '0');
    final String hour = this.hour.toString().padLeft(2, '0');
    final String minute = this.minute.toString().padLeft(2, '0');
    final String second = this.second.toString().padLeft(2, '0');
    final IfdValue value = IfdValueAscii('$year:$month:$day $hour:$minute:$second');
    return <int, IfdValue>{
      exifTagNameToID[tagName]!: value,
    };
  }
}
