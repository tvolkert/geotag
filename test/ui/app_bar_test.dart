import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/ui/home.dart';

import '../src/common.dart';

Future<void> main() async {
  testGeotag('AppBar disables save button when it was active and modified files are deleted', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    await tester.pumpWidget(const MaterialApp(home: GeotagHome()));

    // Load an item
    await root.addFiles(images.paths.take(1)).drain<void>();
    await tester.pump();
    final Finder findSaveButton = find.widgetWithIcon(IconButton, Icons.save);
    IconButton getSaveButton() => tester.widget(findSaveButton) as IconButton;
    expect(findSaveButton, findsOneWidget);
    expect(getSaveButton().onPressed, isNull);

    // Modify the item
    root[0]
      ..dateTimeOriginal = tester.binding.clock.now()
      ..isModified = true
      ..lastModified =  tester.binding.clock.now();
    await root[0].commit();
    await tester.pump();
    expect(getSaveButton().onPressed, isNotNull);

    // Delete the item
    await root.deleteFiles().drain<void>();
    await tester.pump();
    expect(getSaveButton().onPressed, isNull);
  });
}
