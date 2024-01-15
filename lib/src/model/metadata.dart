import 'dart:typed_data';

import 'gps.dart';

class Metadata {
  const Metadata({
    required this.thumbnail,
    required this.photoPath,
    required this.dateTimeOriginal,
    required this.dateTimeDigitized,
    required this.coordinates,
  });

  /// JPG byte data representing a thumbnail of the item.
  final Uint8List thumbnail;

  /// The path to the photo representation of the media item.
  final String photoPath;

  /// The "original date/time" value associated with this media item, if any.
  ///
  /// The "original date/time" value is the timestamp of when the media item
  /// was orignally created, even if it was not digitized until later. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  final DateTime? dateTimeOriginal;

  /// The "date/time digitized" value associated with this media item, if any.
  ///
  /// The "date/time digitized" value is the timestamp of when the media item
  /// was orignally digitized, even if it was created before that time. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  final DateTime? dateTimeDigitized;

  /// The GPS coordinates where the item was created, or null if no such
  /// metadata is attached to the item.
  final GpsCoordinates? coordinates;
}
