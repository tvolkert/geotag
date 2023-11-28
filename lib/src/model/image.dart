import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

import 'gps.dart';

class JpegFile {
  JpegFile(this.path)
      : assert(path.toLowerCase().endsWith('jpg') || path.toLowerCase().endsWith('.jpeg'));

  final String path;

  Image _decode() {
    // Read the image file
    File file = File(path);
    Uint8List bytes = file.readAsBytesSync();
    final Image? image = decodeJpg(bytes);
    if (image == null) {
      throw 'Error: Unable to decode image: $path';
    }
    return image;
  }

  void setGpsCoordinates(GpsCoordinates coords) {
    try {
      final Image image = _decode();
      image.exif.gpsIfd.data.addAll(coords.exifData);
      final File file = File(path);
      file.writeAsBytesSync(encodeJpg(image));
    } on ImageException catch (error) {
      print('ERROR: $error');
    }
  }

  GpsCoordinates? getGpsCoordinates() {
    try {
      final Image image = _decode();
      final GpsLatitude latitude = GpsLatitude.fromExif(image.exif.gpsIfd);
      final GpsLongitude longitude = GpsLongitude.fromExif(image.exif.gpsIfd);
      return GpsCoordinates.raw(latitude, longitude);
    } on ImageException catch (error) {
      print('ERROR: $error');
      return null;
    } on EmptyExifException {
      print('EMPTY');
      return null;
    }
  }
}
