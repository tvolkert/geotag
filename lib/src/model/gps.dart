import 'package:image/image.dart';
import 'package:image/src/util/rational.dart'; // ignore: implementation_imports

class EmptyExifException extends Error {}

class GpsCoordinates {
  GpsCoordinates(double latitude, double longitude)
      : latitude = GpsLatitude(latitude),
        longitude = GpsLongitude(longitude);

  const GpsCoordinates.raw(this.latitude, this.longitude);

  factory GpsCoordinates.fromString(String value) {
    final List<String> values = value.split(', ');
    if (values.length != 2) {
      throw ArgumentError(value);
    }
    final double latitude = double.parse(values[0]);
    final double longitude = double.parse(values[1]);
    return GpsCoordinates(latitude, longitude);
  }

  final GpsLatitude latitude;
  final GpsLongitude longitude;

  Map<int, IfdValue> get exifData {
    return <int, IfdValue>{
      latitude._refTag: latitude.ref,
      latitude._tag: latitude.ifd,
      longitude._refTag: longitude.ref,
      longitude._tag: longitude.ifd,
    };
  }

  @override
  String toString() => '$latitude, $longitude';
}

abstract base class GpsCoordinate {
  const GpsCoordinate._(
    this._value,
    this._tagName,
    this._refTagName,
    this._refIfPositive,
    this._refIfNegative,
  );

  final double _value;
  final String _tagName;
  final String _refTagName;
  final String _refIfPositive;
  final String _refIfNegative;

  int get _tag => exifTagNameToID[_tagName]!;

  int get _refTag => exifTagNameToID[_refTagName]!;

  double get value => _value;

  IfdValue get ifd {
    double localValue = _value.abs();
    final int degrees = localValue.floor();
    localValue = (localValue - degrees) * 60;
    final int minutes = localValue.floor();
    localValue = (localValue - minutes) * 60000;
    final int seconds = localValue.round();
    return IfdValueRational.list(<Rational>[
      Rational(degrees, 1),
      Rational(minutes, 1),
      Rational(seconds, 1000),
    ]);
  }

  IfdValue get ref => IfdValueAscii(_value >= 0 ? _refIfPositive : _refIfNegative);

  @override
  toString() => '$_value';
}

final class GpsLatitude extends GpsCoordinate {
  const GpsLatitude(double value) : super._(value, tagName, refName, north, south);

  GpsLatitude.fromExif(IfdDirectory ifd) : this(_getValue(ifd));

  static const String tagName = 'GPSLatitude';
  static const String refName = 'GPSLatitudeRef';
  static const String north = 'N';
  static const String south = 'S';

  static double _getValue(IfdDirectory ifd) {
    final Map<int, IfdValue> gpsData = ifd.data;
    final IfdValue? latitude = gpsData[exifTagNameToID[tagName]];
    final IfdValue? ref = gpsData[exifTagNameToID[refName]];
    if (latitude == null || ref == null) {
      throw EmptyExifException();
    }
    assert(latitude.type == IfdValueType.rational);
    assert(latitude.length == 3);
    assert(ref.type == IfdValueType.ascii);
    final double degrees = latitude.toDouble(0);
    final double minutes = latitude.toDouble(1);
    final double seconds = latitude.toDouble(2);
    double result = degrees + minutes / 60 + seconds / (60 * 60);
    if (ref.toString() == south) {
      result *= -1;
    }
    return result;
  }
}

final class GpsLongitude extends GpsCoordinate {
  const GpsLongitude(double value) : super._(value, tagName, refName, east, west);

  GpsLongitude.fromExif(IfdDirectory ifd) : this(_getValue(ifd));

  static const String tagName = 'GPSLongitude';
  static const String refName = 'GPSLongitudeRef';
  static const String east = 'E';
  static const String west = 'W';

  static double _getValue(IfdDirectory ifd) {
    final Map<int, IfdValue> gpsData = ifd.data;
    final IfdValue? longitude = gpsData[exifTagNameToID[tagName]];
    final IfdValue? ref = gpsData[exifTagNameToID[refName]];
    if (longitude == null || ref == null) {
      throw EmptyExifException();
    }
    assert(longitude.type == IfdValueType.rational);
    assert(longitude.length == 3);
    assert(ref.type == IfdValueType.ascii);
    final double degrees = longitude.toDouble(0);
    final double minutes = longitude.toDouble(1);
    final double seconds = longitude.toDouble(2);
    double result = degrees + minutes / 60 + seconds / (60 * 60);
    if (ref.toString() == west) {
      result *= -1;
    }
    return result;
  }
}
