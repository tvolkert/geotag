import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/ui/home.dart';
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

  testGeotag('ThumbnailList produces thumbnails when items are added to root', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNothing);

    await MediaBinding.instance.items.addFiles(images.paths).drain<void>();
    await tester.pump();
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

  testGeotag('Adding event to multiple items while the no-event filter is applied', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    await MediaBinding.instance.items.addFiles(images.paths.take(3)).drain<void>();
    await tester.pumpWidget(const MaterialApp(home: GeotagHome()));
    expect(find.byType(Thumbnail), findsNWidgets(3));

    // Turn on the event filter
    await tester.tap(find.byTooltip('Show only missing event'));
    await tester.pump();
    expect(find.byType(Thumbnail), findsNWidgets(3));

    // Select the second and third thumbnails
    await tester.selectThumbnailsAt(<int>[1, 2]);

    // Add an event to the last item
    root[1]..event = 'event'..isModified = true..lastModified = tester.binding.clock.now();
    await root[1].commit();
    root[2]..event = 'event'..isModified = true..lastModified = tester.binding.clock.now();
    await root[2].commit();
    await tester.pump();
    expect(find.byType(Thumbnail), findsNWidgets(1));
  });
}
