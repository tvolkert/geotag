import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/ui/thumbnail_list.dart';

import '../src/common.dart';

Future<void> main() async {
  testGeotag('ThumbnailList produces no thumbnails if items is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNothing);
  });

  testGeotag('ThumbnailList produces thumbnails if items is not empty', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNWidgets(images.length));
  });

  testGeotag('filter by missing date works', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    await tester.tap(find.byTooltip('Show only missing date'));
    await tester.pump();
    expect(find.byType(Thumbnail), findsNWidgets(3));
  });

  testGeotag('filter by missing geo works', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    await tester.tap(find.byTooltip('Show only missing geotag'));
    await tester.pump();
    expect(find.byType(Thumbnail), findsNWidgets(3));
  });
}
