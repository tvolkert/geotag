import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/files.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/ui/preview_panel.dart';
import 'package:geotag/src/ui/video_player.dart';

import '../src/common.dart';

File _imageFile(String filename) {
  return FilesBinding.instance.fs.file('/support/media/images/$filename');
}

Future<void> main() async {
  testGeotag('PreviewPanel correctly updates when items change relative order due to update', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items..comparator = const ByDate(Ascending());
    final List<String> imagePaths = images.paths.toList();
    await root.addFiles(imagePaths).drain<void>();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1, 2]);
    final MediaItems selected = root.where(filter);
    final VideoPlayerPlayPauseController playPauseController = VideoPlayerPlayPauseController();
    await tester.pumpWidget(
      MaterialApp(
        home: PreviewPanel(
          items: selected,
          playPauseController: playPauseController,
        ),
      ),
    );

    root[1].dateTimeOriginal = DateTime(2024);
    await root[1].commit();
    expect(filter.indexes, <int>[1, 4]);
    await tester.pump();
    expect(find.image(FileImage(_imageFile('oneByOneWhite.jpg'), scale: 1)), findsOne);
    expect(find.image(FileImage(_imageFile('oneByOneBlackJpgWithGeo.jpg'), scale: 1)), findsOne);
  });
}
