import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/ui/thumbnail_list.dart';

import '../src/binding.dart';

Future<void> main() async {
  setUp(() async {
    await TestGeotagAppBinding.ensureInitialized();
  });

  testWidgets('ThumbnailList produces no thumbnails if items is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ThumbnailList(),
      ),
    );
    expect(find.byType(Thumbnail), findsNothing);
  });
}
