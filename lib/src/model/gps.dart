import 'package:image/image.dart';
import 'package:image/src/util/rational.dart';

class GpsCoordinates {
  GpsCoordinates(double latitude, double longitude) :
      this.latitude = GpsLatitude(latitude),
      this.longitude = GpsLongitude(longitude);

  const GpsCoordinates.raw(this.latitude, this.longitude);

  final GpsLatitude latitude;
  final GpsLongitude longitude;

  Map<int, IfdValue> get exifData {
    return <int, IfdValue>{
      latitude._refTag: latitude.ref,
      latitude._tag: latitude.value,
      longitude._refTag: longitude.ref,
      longitude._tag: longitude.value,
    };
  }
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

  IfdValue get value {
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
}

final class GpsLatitude extends GpsCoordinate {
  const GpsLatitude(double value) : super._(value, 'GPSLatitude', 'GPSLatitudeRef', 'N', 'S');
}

final class GpsLongitude extends GpsCoordinate {
  const GpsLongitude(double value) : super._(value, 'GPSLongitude', 'GPSLongitudeRef', 'E', 'W');
}
