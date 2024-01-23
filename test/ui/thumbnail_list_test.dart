import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/foundation/debug.dart';
import 'package:geotag/src/ui/thumbnail_list.dart';

import '../src/binding.dart';
import '../src/common.dart';

Future<void> main() async {
  late ImageReferences images;

  setUpAll(() async {
    debugUseRealIsolates = false;
    await TestGeotagAppBinding.ensureInitialized();
    images = loadImages();
  });

  tearDownAll(() {
    debugUseRealIsolates = true;
  });

  testWidgets('ThumbnailList produces no thumbnails if items is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNothing);
  });

  testWidgets('ThumbnailList produces thumbnails if items is not empty', (WidgetTester tester) async {
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    addTearDown(() => MediaBinding.instance.items.deleteFiles().drain<void>());

    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNWidgets(images.length));
  });

  testWidgets('filter by missing date works', (WidgetTester tester) async {
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    addTearDown(() => MediaBinding.instance.items.deleteFiles().drain<void>());

    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    await tester.tap(find.byTooltip('Show only missing date'));
    await tester.pump();
    expect(find.byType(Thumbnail), findsNWidgets(3));
  });

  testWidgets('filter by missing geo works', (WidgetTester tester) async {
    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    addTearDown(() => MediaBinding.instance.items.deleteFiles().drain<void>());

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
