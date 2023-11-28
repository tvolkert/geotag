import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart';

import 'package:geotag/src/model/gps.dart';

void updateExifData(String filename, double latitude, double longitude) {
  // Check if the file is a JPEG file
  if (!filename.toLowerCase().endsWith('.jpg') && !filename.toLowerCase().endsWith('.jpeg')) {
    print('Error: The provided file must be a JPEG file.');
    return;
  }

  // Read the image file
  File file = File(filename);
  Uint8List bytes = file.readAsBytesSync();
  final Image? image = decodeJpg(bytes);
  if (image == null) {
    print('Error: Unable to decode image: $filename');
    return;
  }

  // Set GPS information
  final GpsCoordinates coords = GpsCoordinates(latitude, longitude);
  image.exif.gpsIfd.data.addAll(coords.exifData);

  // Save the updated image back to the file system
  File updatedFile = File(filename.replaceAll('.jpg', '_updated.jpg'));
  updatedFile.writeAsBytesSync(encodeJpg(image));

  print('EXIF data updated and file saved: ${updatedFile.path}');
}
