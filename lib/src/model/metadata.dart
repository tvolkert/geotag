import 'dart:typed_data';

import 'gps.dart';

class Metadata {
  const Metadata({
    required this.thumbnail,
    required this.dateTime,
    required this.coordinates,
  });

  /// JPG byte data representing a thumbnail of the item.
  final Uint8List thumbnail;

  /// The date / time that the item was created, or null if no such metadata is
  /// attached to the item.
  final DateTime? dateTime;

  /// The GPS coordinates where the item was created, or null if no such
  /// metadata is attached to the item.
  final GpsCoordinates? coordinates;
}
