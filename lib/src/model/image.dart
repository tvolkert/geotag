// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart';

import '../extensions/date_time.dart';
import 'exif.dart';
import 'gps.dart';

class JpegFile {
  JpegFile(this.path) : assert(allowedExtensions.contains(path.toLowerCase().split('.').last));

  final String path;
  Image? _image;

  static Set<String> allowedExtensions = <String>{'jpg', 'jpeg'};

  @protected
  Image get image => _image ??= _decode();

  Uint8List get bytes => image.toUint8List();

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

  void write() {
    try {
      final File file = File(path);
      file.writeAsBytesSync(encodeJpg(image));
    } on ImageException catch (error) {
      print('ERROR: $error');
    }
  }

  GpsCoordinates? getGpsCoordinates() {
    try {
      final GpsLatitude latitude = GpsLatitude.fromExif(image.exif.gpsIfd);
      final GpsLongitude longitude = GpsLongitude.fromExif(image.exif.gpsIfd);
      return GpsCoordinates.raw(latitude, longitude);
    } on EmptyExifException {
      print('EMPTY');
      return null;
    }
  }

  void setGpsCoordinates(GpsCoordinates coords) {
    image.exif.gpsIfd.data.addAll(coords.exifData);
  }

  DateTime? getDateTimeOriginal() => ExifDateTime.original(image.exif.imageIfd);

  void setDateTimeOriginal(DateTime dateTime) {
    image.exif.exifIfd.data.addAll(dateTime.exifDataAsOriginal);
    image.exif.imageIfd.data.addAll(dateTime.exifDataAsOriginal);
  }

  DateTime? getDateTimeDigitized() => ExifDateTime.digitized(image.exif.imageIfd);

  void setDateTimeDigitized(DateTime dateTime) {
    image.exif.exifIfd.data.addAll(dateTime.exifDataAsDigitized);
    image.exif.imageIfd.data.addAll(dateTime.exifDataAsDigitized);
  }
}
