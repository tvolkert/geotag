// ignore_for_file: avoid_print

import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart';

import '../extensions/date_time.dart';
import 'exif.dart';
import 'gps.dart';
import 'metadata.dart';

class JpegFile {
  /// The file system specified by [fs] will be used to resolve the file
  /// located at [path].
  JpegFile(this.path, this.fs)
      : assert(allowedExtensions.contains(path.toLowerCase().split('.').last));

  final String path;
  final FileSystem fs;
  Image? _image;

  static Set<String> allowedExtensions = <String>{'jpg', 'jpeg'};

  @protected
  Image get image => _image ??= _decode();

  Metadata extractMetadata() {
    final Uint8List thumbnailBytes = getThumbnailBytes();
    final GpsCoordinates? coordinates = getGpsCoordinates();
    final DateTime? dateTimeOriginal = getDateTimeOriginal();
    final DateTime? dateTimeDigitized = getDateTimeDigitized();
    return Metadata(
      thumbnail: thumbnailBytes,
      photoPath: path,
      dateTimeOriginal: dateTimeOriginal,
      dateTimeDigitized: dateTimeDigitized,
      coordinates: coordinates,
    );
  }

  /// [size] represents the square bounding box inside which the extracted
  /// frame must fit.
  ///
  /// [quality] values range from 1 to 100, with 1 being the lowest quality and
  /// 100 being the highest quality. The higher the quality, the larger the file
  /// size.
  Uint8List getThumbnailBytes({
    int size = 320,
    int quality = 80,
  }) {
    final Size sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final BoxConstraints constraints = BoxConstraints.loose(Size.square(size.toDouble()));
    final Size targetSize = constraints.constrainSizeAndAttemptToPreserveAspectRatio(sourceSize);
    final int targetWidth = targetSize.width.round();
    final int targetHeight = targetSize.height.round();
    final Image resized = copyResize(image, width: targetWidth, height: targetHeight);
    return encodeJpg(resized, quality: quality);
  }

  Uint8List get bytes => image.toUint8List();

  Image _decode() {
    // Read the image file
    final File file = fs.file(path);
    final Uint8List bytes = file.readAsBytesSync();
    final Image? image = decodeJpg(bytes);
    if (image == null) {
      throw 'Error: Unable to decode image: $path';
    }
    return image;
  }

  void write() {
    try {
      final File file = fs.file(path);
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
      return null;
    }
  }

  void setGpsCoordinates(GpsCoordinates coords) {
    image.exif.gpsIfd.data.addAll(coords.exifData);
  }

  DateTime? getDateTimeOriginal() {
    for (IfdDirectory ifd in <IfdDirectory>[image.exif.exifIfd, image.exif.imageIfd]) {
      final DateTime? value = ExifDateTime.original(ifd);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  void setDateTimeOriginal(DateTime dateTime) {
    for (IfdDirectory ifd in <IfdDirectory>[image.exif.exifIfd, image.exif.imageIfd]) {
      ifd.data.addAll(dateTime.exifDataAsOriginal);
    }
  }

  DateTime? getDateTimeDigitized() {
    for (IfdDirectory ifd in <IfdDirectory>[image.exif.exifIfd, image.exif.imageIfd]) {
      final DateTime? value = ExifDateTime.digitized(ifd);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  void setDateTimeDigitized(DateTime dateTime) {
    for (IfdDirectory ifd in <IfdDirectory>[image.exif.exifIfd, image.exif.imageIfd]) {
      ifd.data.addAll(dateTime.exifDataAsDigitized);
    }
  }
}
