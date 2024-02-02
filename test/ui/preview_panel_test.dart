import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/ui/home.dart';
import 'package:geotag/src/ui/photo_pile.dart';

import '../src/common.dart';

extension _WidgetTesterBrevityExtensions on WidgetTester {
  _ImageExpectations expectImageAt(int index) {
    final Finder image = find.descendant(of: find.byType(PhotoPile), matching: find.byType(Image));
    return _ImageExpectations(widget<Image>(image.at(index)).image);
  }
}

class _ImageExpectations {
  const _ImageExpectations(this.image);

  final ImageProvider image;

  void isFileNamed(String filename) {
    expect(image, isA<FileImage>());
    expect((image as FileImage).file.path, endsWith(filename));
  }
}

Future<void> main() async {
  testGeotag('PreviewPanel correctly updates when items change relative order due to update', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items..comparator = const ByDate(Ascending());
    await root.addFiles(images.paths).drain<void>();
    await tester.pumpWidget(const MaterialApp(home: GeotagHome()));

    // Select the second and third thumbnails
    await tester.selectThumbnailsAt(<int>[1, 2]);
    tester.expectImageAt(0).isFileNamed('oneByOneWhite.jpg');
    tester.expectImageAt(1).isFileNamed('oneByOneBlackJpgWithGeo.jpg');

    // Edit the date on the first item to push it to the end of the root list
    root[1].dateTimeOriginal = DateTime(2024);
    await root[1].commit();
    await tester.pump();
    tester.expectImageAt(0).isFileNamed('oneByOneBlackJpgWithGeo.jpg');
    tester.expectImageAt(1).isFileNamed('oneByOneWhite.jpg');
  });
}
