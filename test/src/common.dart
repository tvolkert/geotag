import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/db.dart';
import 'package:geotag/src/bindings/debug.dart';
import 'package:geotag/src/bindings/files.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/foundation/debug.dart';
import 'package:meta/meta.dart';

import 'binding.dart';

/// Signature for callback to [testWidgets] and [benchmarkWidgets].
typedef GeotagTesterCallback = Future<void> Function(
  WidgetTester widgetTester,
  ImageReferences images,
);

@isTest
void testGeotag(String description, WidgetTesterCallback callback) {
  testWidgets(description, (WidgetTester tester) async {
    debugUseRealIsolates = false;
    debugAllowBindingReinitialization = true;
    addTearDown(() => debugUseRealIsolates = true);
    addTearDown(() => debugAllowBindingReinitialization = false);
    await TestGeotagAppBinding.ensureInitialized(reinitialize: true);
    await callback(tester);
  });
}

int _nextItemId = 1;

extension WidgetTesterExtensions on WidgetTester {
  /// Loads the specified images onto the [FilesBinding.fs] file system and
  /// returns the paths to the files that were created.
  ImageReferences loadImages({
    String oneByOneBlack = '/images/oneByOneBlack.jpg',
    String oneByOneWhite = '/images/oneByOneWhite.jpg',
    String oneByOneBlackJpgWithDate = '/images/oneByOneBlackJpgWithDate.jpg',
    String oneByOneBlackJpgWithGeo = '/images/oneByOneBlackJpgWithGeo.jpg',
    String oneByOneBlackJpgWithDateAndGeo = '/images/oneByOneBlackJpgWithDateAndGeo.jpg',
  }) {
    final ImageReferences images = ImageReferences(
      oneByOneBlack: oneByOneBlack,
      oneByOneWhite: oneByOneWhite,
      oneByOneBlackJpgWithDate: oneByOneBlackJpgWithDate,
      oneByOneBlackJpgWithGeo: oneByOneBlackJpgWithGeo,
      oneByOneBlackJpgWithDateAndGeo: oneByOneBlackJpgWithDateAndGeo,
    );

    for (String path in images.paths) {
      final File file = FilesBinding.instance.fs.file(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
    }

    final FileSystem fs = FilesBinding.instance.fs;
    fs.file(oneByOneBlack).writeAsBytesSync(oneByOneBlackJpgBytes);
    fs.file(oneByOneWhite).writeAsBytesSync(oneByOneWhiteJpgBytes);
    fs.file(oneByOneBlackJpgWithDate).writeAsBytesSync(oneByOneBlackJpgWithDateBytes);
    fs.file(oneByOneBlackJpgWithGeo).writeAsBytesSync(oneByOneBlackJpgWithGeoBytes);
    fs.file(oneByOneBlackJpgWithDateAndGeo).writeAsBytesSync(oneByOneBlackJpgWithDateAndGeoBytes);

    return images;
  }

  DbRow newDbRow({
    required String path,
    MediaType type = MediaType.photo,
    String? photoPath,
    Uint8List? thumbnail,
    String? latlng,
    String? event,
  }) {
    return DbRow.from(<String, Object?>{
      'ITEM_ID': _nextItemId++,
      'TYPE': type,
      'PATH': path,
      'PHOTO_PATH': photoPath ?? path,
      'THUMBNAIL': thumbnail,
      'LATLNG': latlng,
      'DATETIME_ORIGINAL': binding.clock.now().millisecondsSinceEpoch,
      'DATETIME_DIGITIZED': binding.clock.now().millisecondsSinceEpoch,
      'EVENT': event,
      'MODIFIED': 0,
      'DATETIME_LAST_MODIFIED': binding.clock.now().millisecondsSinceEpoch,
    });
  }

  MediaItem newMediaItem({
    required String path,
    MediaType type = MediaType.photo,
    String? photoPath,
    Uint8List? thumbnail,
    String? latlng,
    String? event,
  }) {
    return MediaItem.fromDbRow(newDbRow(
      path: path,
      type: type,
      photoPath: photoPath,
      thumbnail: thumbnail,
      latlng: latlng,
      event: event,
    ));
  }
}

/// Contains the file system paths of images that were loaded with [loadImages].
///
/// Once [loadImages] has been called, these paths will reference valid image
/// files on the [FilesBinding.fs] file system.
class ImageReferences {
  const ImageReferences({
    required this.oneByOneBlack,
    required this.oneByOneWhite,
    required this.oneByOneBlackJpgWithDate,
    required this.oneByOneBlackJpgWithGeo,
    required this.oneByOneBlackJpgWithDateAndGeo,
  });

  final String oneByOneBlack;
  final String oneByOneWhite;
  final String oneByOneBlackJpgWithDate;
  final String oneByOneBlackJpgWithGeo;
  final String oneByOneBlackJpgWithDateAndGeo;

  int get length => paths.length;

  Iterable<String> get paths {
    return <String>[
      oneByOneBlack,
      oneByOneWhite,
      oneByOneBlackJpgWithDate,
      oneByOneBlackJpgWithGeo,
      oneByOneBlackJpgWithDateAndGeo,
    ];
  }
}

/// Date: <unset>
/// Geo: <unset>
final Uint8List oneByOneBlackJpgBytes = Uint8List.fromList(<int>[
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, //
  72, 0, 72, 0, 0, 255, 254, 0, 19, 67, 114, 101, 97, 116, 101, //
  100, 32, 119, 105, 116, 104, 32, 71, 73, 77, 80, 255, 219, 0, 67, //
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 255, 219, 0, 67, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 255, //
  192, 0, 17, 8, 0, 1, 0, 1, 3, 1, 17, 0, 2, 17, 1, //
  3, 17, 1, 255, 196, 0, 20, 0, 1, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 255, 196, 0, 20, 16, //
  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 255, 196, 0, 20, 1, 1, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 196, 0, 20, 17, 1, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 255, 218, 0, 12, 3, 1, 0, 2, 17, 3, 17, 0, 63, 0, //
  63, 240, 127, 255, 217, //
]);

/// Date: <unset>
/// Geo: <unset>
final Uint8List oneByOneWhiteJpgBytes = Uint8List.fromList(<int>[
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, //
  72, 0, 72, 0, 0, 255, 219, 0, 67, 0, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 255, //
  219, 0, 67, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 255, 192, 0, 17, 8, 0, 1, //
  0, 1, 3, 1, 17, 0, 2, 17, 1, 3, 17, 1, 255, 196, 0, //
  20, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 10, 255, 196, 0, 20, 16, 1, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 196, 0, 20, //
  1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 255, 196, 0, 20, 17, 1, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 218, 0, 12, 3, //
  1, 0, 2, 17, 3, 17, 0, 63, 0, 127, 0, 255, 217, //
]);

/// Date: 2020:03:13 19:00:00 (COVID lockdown)
/// Geo: <unset>
final Uint8List oneByOneBlackJpgWithDateBytes = Uint8List.fromList(<int>[
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, //
  72, 0, 72, 0, 0, 255, 225, 0, 216, 69, 120, 105, 102, 0, 0, //
  77, 77, 0, 42, 0, 0, 0, 8, 0, 5, 1, 26, 0, 5, 0, //
  0, 0, 1, 0, 0, 0, 74, 1, 27, 0, 5, 0, 0, 0, 1, //
  0, 0, 0, 82, 1, 40, 0, 3, 0, 0, 0, 1, 0, 2, 0, //
  0, 2, 19, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 135, 105, //
  0, 4, 0, 0, 0, 1, 0, 0, 0, 90, 0, 0, 0, 0, 0, //
  0, 0, 72, 0, 0, 0, 1, 0, 0, 0, 72, 0, 0, 0, 1, //
  0, 6, 144, 0, 0, 7, 0, 0, 0, 4, 48, 50, 51, 50, 144, //
  3, 0, 2, 0, 0, 0, 20, 0, 0, 0, 168, 144, 4, 0, 2, //
  0, 0, 0, 20, 0, 0, 0, 188, 145, 1, 0, 7, 0, 0, 0, //
  4, 1, 2, 3, 0, 160, 0, 0, 7, 0, 0, 0, 4, 48, 49, //
  48, 48, 160, 1, 0, 3, 0, 0, 0, 1, 255, 255, 0, 0, 0, //
  0, 0, 0, 50, 48, 50, 48, 58, 48, 51, 58, 49, 51, 32, 49, //
  57, 58, 48, 48, 58, 48, 48, 0, 50, 48, 50, 48, 58, 48, 51, //
  58, 49, 51, 32, 49, 57, 58, 48, 48, 58, 48, 48, 0, 255, 254, //
  0, 19, 67, 114, 101, 97, 116, 101, 100, 32, 119, 105, 116, 104, 32, //
  71, 73, 77, 80, 255, 219, 0, 67, 0, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 255, 219, //
  0, 67, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 255, 192, 0, 17, 8, 0, 1, 0, //
  1, 3, 1, 17, 0, 2, 17, 1, 3, 17, 1, 255, 196, 0, 20, //
  0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 11, 255, 196, 0, 20, 16, 1, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 196, 0, 20, 1, //
  1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 255, 196, 0, 20, 17, 1, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 218, 0, 12, 3, 1, //
  0, 2, 17, 3, 17, 0, 63, 0, 63, 240, 127, 255, 217, //
]);

/// Date: <unset>
/// Geo: 37.42, -122.08 (Google campus)
final Uint8List oneByOneBlackJpgWithGeoBytes = Uint8List.fromList(<int>[
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, //
  72, 0, 72, 0, 0, 255, 225, 0, 212, 69, 120, 105, 102, 0, 0, //
  77, 77, 0, 42, 0, 0, 0, 8, 0, 5, 1, 26, 0, 5, 0, //
  0, 0, 1, 0, 0, 0, 74, 1, 27, 0, 5, 0, 0, 0, 1, //
  0, 0, 0, 82, 1, 40, 0, 3, 0, 0, 0, 1, 0, 2, 0, //
  0, 2, 19, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 136, 37, //
  0, 4, 0, 0, 0, 1, 0, 0, 0, 90, 0, 0, 0, 0, 0, //
  0, 0, 72, 0, 0, 0, 1, 0, 0, 0, 72, 0, 0, 0, 1, //
  0, 5, 0, 0, 0, 1, 0, 0, 0, 4, 2, 3, 0, 0, 0, //
  1, 0, 2, 0, 0, 0, 2, 78, 0, 0, 0, 0, 2, 0, 5, //
  0, 0, 0, 3, 0, 0, 0, 156, 0, 3, 0, 2, 0, 0, 0, //
  2, 87, 0, 0, 0, 0, 4, 0, 5, 0, 0, 0, 3, 0, 0, //
  0, 180, 0, 0, 0, 0, 0, 0, 0, 37, 0, 0, 0, 1, 0, //
  0, 0, 25, 0, 0, 0, 1, 0, 0, 0, 12, 0, 0, 0, 1, //
  0, 0, 0, 122, 0, 0, 0, 1, 0, 0, 0, 4, 0, 0, 0, //
  1, 0, 0, 0, 48, 0, 0, 0, 1, 255, 254, 0, 19, 67, 114, //
  101, 97, 116, 101, 100, 32, 119, 105, 116, 104, 32, 71, 73, 77, 80, //
  255, 219, 0, 67, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 255, 219, 0, 67, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 255, 192, 0, 17, 8, 0, 1, 0, 1, 3, 1, 17, //
  0, 2, 17, 1, 3, 17, 1, 255, 196, 0, 20, 0, 1, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 255, //
  196, 0, 20, 16, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 255, 196, 0, 20, 1, 1, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 196, //
  0, 20, 17, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 255, 218, 0, 12, 3, 1, 0, 2, 17, 3, //
  17, 0, 63, 0, 63, 240, 127, 255, 217, //
]);

/// Date: 2020:03:13 19:00:00 (COVID lockdown)
/// Geo: 37.42, -122.08 (Google campus)
final Uint8List oneByOneBlackJpgWithDateAndGeoBytes = Uint8List.fromList(<int>[
  255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, //
  72, 0, 72, 0, 0, 255, 225, 1, 86, 69, 120, 105, 102, 0, 0, //
  77, 77, 0, 42, 0, 0, 0, 8, 0, 6, 1, 26, 0, 5, 0, //
  0, 0, 1, 0, 0, 0, 86, 1, 27, 0, 5, 0, 0, 0, 1, //
  0, 0, 0, 94, 1, 40, 0, 3, 0, 0, 0, 1, 0, 2, 0, //
  0, 2, 19, 0, 3, 0, 0, 0, 1, 0, 1, 0, 0, 135, 105, //
  0, 4, 0, 0, 0, 1, 0, 0, 0, 102, 136, 37, 0, 4, 0, //
  0, 0, 1, 0, 0, 0, 220, 0, 0, 0, 0, 0, 0, 0, 72, //
  0, 0, 0, 1, 0, 0, 0, 72, 0, 0, 0, 1, 0, 6, 144, //
  0, 0, 7, 0, 0, 0, 4, 48, 50, 51, 50, 144, 3, 0, 2, //
  0, 0, 0, 20, 0, 0, 0, 180, 144, 4, 0, 2, 0, 0, 0, //
  20, 0, 0, 0, 200, 145, 1, 0, 7, 0, 0, 0, 4, 1, 2, //
  3, 0, 160, 0, 0, 7, 0, 0, 0, 4, 48, 49, 48, 48, 160, //
  1, 0, 3, 0, 0, 0, 1, 255, 255, 0, 0, 0, 0, 0, 0, //
  50, 48, 50, 48, 58, 48, 51, 58, 49, 51, 32, 49, 57, 58, 48, //
  48, 58, 48, 48, 0, 50, 48, 50, 48, 58, 48, 51, 58, 49, 51, //
  32, 49, 57, 58, 48, 48, 58, 48, 48, 0, 0, 5, 0, 0, 0, //
  1, 0, 0, 0, 4, 2, 3, 0, 0, 0, 1, 0, 2, 0, 0, //
  0, 2, 78, 0, 0, 0, 0, 2, 0, 5, 0, 0, 0, 3, 0, //
  0, 1, 30, 0, 3, 0, 2, 0, 0, 0, 2, 87, 0, 0, 0, //
  0, 4, 0, 5, 0, 0, 0, 3, 0, 0, 1, 54, 0, 0, 0, //
  0, 0, 0, 0, 37, 0, 0, 0, 1, 0, 0, 0, 25, 0, 0, //
  0, 1, 0, 0, 0, 12, 0, 0, 0, 1, 0, 0, 0, 122, 0, //
  0, 0, 1, 0, 0, 0, 4, 0, 0, 0, 1, 0, 0, 0, 48, //
  0, 0, 0, 1, 255, 254, 0, 19, 67, 114, 101, 97, 116, 101, 100, //
  32, 119, 105, 116, 104, 32, 71, 73, 77, 80, 255, 219, 0, 67, 0, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 255, 219, 0, 67, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, //
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 255, 192, //
  0, 17, 8, 0, 1, 0, 1, 3, 1, 17, 0, 2, 17, 1, 3, //
  17, 1, 255, 196, 0, 20, 0, 1, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 11, 255, 196, 0, 20, 16, 1, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 255, 196, 0, 20, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 255, 196, 0, 20, 17, 1, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  255, 218, 0, 12, 3, 1, 0, 2, 17, 3, 17, 0, 63, 0, 63, //
  240, 127, 255, 217, //
]);
