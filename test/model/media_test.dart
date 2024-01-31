import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/bindings/media.dart';
import 'package:geotag/src/model/media.dart';

import '../src/common.dart';

typedef UpdateMediaItemCallback = void Function(MediaItem item);
typedef ImagesToPathsCallback = Iterable<String> Function(ImageReferences images);

extension _DateTimeBrevityExtenions on DateTime {
  int get _mse => millisecondsSinceEpoch;
}

extension _WidgetTesterBrevityExtenions on WidgetTester {
  Future<RootMediaItems> _populateItems([ImagesToPathsCallback? getPaths]) async {
    final ImageReferences images = loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    await root.addFiles(getPaths?.call(images) ?? images.paths).drain<void>();
    return root;
  }
}

extension _MediaItemBrevityExtensions on MediaItem {
  Future<void> _update(UpdateMediaItemCallback callback) async {
    callback(this);
    await commit();
  }
}

bool _needsGeo(MediaItem item) => !item.hasLatlng;

bool _hasGeo(MediaItem item) => item.hasLatlng;

Future<void> main() async {
  testGeotag('Metadata update not visible until commit is called', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    await root.addFiles(<String>[images.oneByOneBlack]).drain<void>();
    bool childMetadataChanged = false;
    root.addMetadataListener(() => childMetadataChanged = true);
    root[0].id = 100;
    expect(root[0].id, 1);
    expect(childMetadataChanged, isFalse);
    root[0].type = MediaType.video;
    expect(root[0].type, MediaType.photo);
    expect(childMetadataChanged, isFalse);
    root[0].path = '/modified_path';
    expect(root[0].path, '/support/media${images.oneByOneBlack}');
    expect(childMetadataChanged, isFalse);
    root[0].photoPath = '/modified_photo_path';
    expect(root[0].photoPath, '/support/media${images.oneByOneBlack}');
    expect(childMetadataChanged, isFalse);
    root[0].thumbnail = Uint8List.fromList(<int>[100, 99, 98]);
    expect(root[0].thumbnail, isNotNull);
    expect(root[0].thumbnail, isNot(Uint8List.fromList(<int>[100, 99, 98])));
    expect(childMetadataChanged, isFalse);
    root[0].latlng = '0,0';
    expect(root[0].latlng, isNull);
    expect(childMetadataChanged, isFalse);
    await tester.pump(const Duration(seconds: 1));
    root[0].dateTimeOriginal = tester.binding.clock.now();
    expect(root[0].dateTimeOriginal, isNull);
    expect(childMetadataChanged, isFalse);
    await tester.pump(const Duration(seconds: 1));
    root[0].dateTimeDigitized = tester.binding.clock.now();
    expect(root[0].dateTimeDigitized, isNull);
    expect(childMetadataChanged, isFalse);
    root[0].event = 'modified event';
    expect(root[0].event, isNull);
    expect(childMetadataChanged, isFalse);
    root[0].isModified = true;
    expect(root[0].isModified, isFalse);
    expect(childMetadataChanged, isFalse);
    await tester.pump(const Duration(seconds: 1));
    root[0].lastModified = tester.binding.clock.now();
    expect(root[0].lastModified._mse, tester.binding.clock.secondsAgo(3)._mse);
    expect(childMetadataChanged, isFalse);
    await root[0].commit();
    expect(childMetadataChanged, isTrue);
    expect(root[0].id, 100);
    expect(root[0].type, MediaType.video);
    expect(root[0].path, '/modified_path');
    expect(root[0].photoPath, '/modified_photo_path');
    expect(root[0].thumbnail, Uint8List.fromList(<int>[100, 99, 98]));
    expect(root[0].latlng, '0,0');
    expect(root[0].dateTimeOriginal!._mse, tester.binding.clock.secondsAgo(2)._mse);
    expect(root[0].dateTimeDigitized!._mse, tester.binding.clock.secondsAgo(1)._mse);
    expect(root[0].event, 'modified event');
    expect(root[0].isModified, isTrue);
    expect(root[0].lastModified._mse, tester.binding.clock.now()._mse);
  });

  testGeotag('Root items notifies only metadata when item is updated but does not move', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    bool rootStructureChanged = false;
    root.addStructureListener(() => rootStructureChanged = true);
    bool itemMetadataChanged = false;
    root.addMetadataListener(() => itemMetadataChanged = true);
    expect(root.length, 5);
    await root[0]._update((MediaItem item) => item.latlng = '0,0');
    expect(root.length, 5);
    expect(rootStructureChanged, isFalse);
    expect(itemMetadataChanged, isTrue);
  });

  testGeotag('Root items notifies structure and metadata when item is updated and moves', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    bool rootStructureChanged = false;
    root.addStructureListener(() => rootStructureChanged = true);
    bool itemMetadataChanged = false;
    root.addMetadataListener(() => itemMetadataChanged = true);
    expect(root.length, 5);
    await root[0]._update((MediaItem item) => item.dateTimeOriginal = tester.binding.clock.now());
    expect(root.length, 5);
    expect(rootStructureChanged, isTrue);
    expect(itemMetadataChanged, isTrue);
  });

  testGeotag('Root items notifies only structure when item is added', (WidgetTester tester) async {
    late final ImageReferences images;
    final RootMediaItems root = await tester._populateItems((ImageReferences img) {
      images = img;
      return <String>[images.oneByOneBlack];
    });
    bool rootStructureChanged = false;
    root.addStructureListener(() => rootStructureChanged = true);
    bool itemMetadataChanged = false;
    root.addMetadataListener(() => itemMetadataChanged = true);
    expect(root.length, 1);
    await root.addFiles(<String>[images.oneByOneWhite]).drain<void>();
    expect(root.length, 2);
    expect(rootStructureChanged, isTrue);
    expect(itemMetadataChanged, isFalse);
  });

  testGeotag('Root items notifies only structure when item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    bool rootStructureChanged = false;
    root.addStructureListener(() => rootStructureChanged = true);
    bool itemMetadataChanged = false;
    root.addMetadataListener(() => itemMetadataChanged = true);
    expect(root.length, 5);
    await root.deleteFiles().drain<void>();
    expect(root.length, 0);
    expect(rootStructureChanged, isTrue);
    expect(itemMetadataChanged, isFalse);
  });

  testGeotag('Root items notifies only structure when comparator is changed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    bool rootStructureChanged = false;
    root.addStructureListener(() => rootStructureChanged = true);
    bool itemMetadataChanged = false;
    root.addMetadataListener(() => itemMetadataChanged = true);
    expect(root.length, 5);
    root.comparator = const ByDate(Ascending());
    expect(root.length, 5);
    expect(rootStructureChanged, isTrue);
    expect(itemMetadataChanged, isFalse);
  });

  testGeotag('Predicate filter updates and notifies when item is updated to not be in filter', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 3);
    final int id = noGeo.last.id;
    await root[0]._update((MediaItem item) => item.latlng = '0,0');
    expect(noGeo.length, 2);
    expect(structureChanged, isTrue);
    expect(noGeo.last.id, id);
  });

  testGeotag('Predicate filter updates and notifies when item is updated to be in filter', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems hasGeo = root.where(const PredicateMediaItemFilter(_hasGeo));
    bool structureChanged = false;
    hasGeo.addStructureListener(() => structureChanged = true);
    expect(hasGeo.length, 2);
    final int id = hasGeo.first.id;
    await root[0]._update((MediaItem item) => item.latlng = '0,0');
    expect(hasGeo.length, 3);
    expect(structureChanged, isTrue);
    expect(hasGeo.first.id, isNot(id));
    expect(hasGeo.first.id, root.first.id);
  });

  testGeotag('Predicate filter updates and notifies when item is inserted that is in the filter', (WidgetTester tester) async {
    late final ImageReferences images;
    final RootMediaItems root = await tester._populateItems((ImageReferences img) {
      images = img;
      return <String>[
        images.oneByOneBlack,
        images.oneByOneBlackJpgWithDate,
        images.oneByOneBlackJpgWithGeo,
        images.oneByOneBlackJpgWithDateAndGeo,
      ];
    });
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 2);
    await root.addFiles(<String>[images.oneByOneWhite]).drain<void>();
    expect(noGeo.length, 3);
    expect(structureChanged, isTrue);
  });

  testGeotag('Predicate filter does not notify when item is inserted that is not in the filter', (WidgetTester tester) async {
    late final ImageReferences images;
    final RootMediaItems root = await tester._populateItems((ImageReferences img) {
      images = img;
      return <String>[
        images.oneByOneBlack,
        images.oneByOneBlackJpgWithDate,
        images.oneByOneBlackJpgWithGeo,
      ];
    });
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 2);
    await root.addFiles(<String>[images.oneByOneBlackJpgWithDateAndGeo]).drain<void>();
    expect(noGeo.length, 2);
    expect(structureChanged, isFalse);
  });

  testGeotag('Predicate filter updates and notifies when item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 3);
    await root.where(IndexedMediaItemFilter(<int>[0])).deleteFiles().drain<void>();
    expect(noGeo.length, 2);
    expect(structureChanged, isTrue);
  });

  testGeotag('Predicate filter updates and notifies when comparator is changed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 3);
    root.comparator = const ByDate(Ascending());
    expect(noGeo.length, 3);
    expect(structureChanged, isTrue);
  });

  testGeotag('Indexed filter does not update or notify when item is updated and stays in place', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    await tester.pump(const Duration(seconds: 1));
    await root[0]._update((MediaItem item) => item.dateTimeOriginal = tester.binding.clock.now());
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[2]);
  });

  testGeotag('Indexed filter updates but does not notify when different item is updated and moves', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.last.id;
    await root[0]._update((MediaItem item) => item.dateTimeOriginal = tester.binding.clock.now());
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[1]);
    expect(selected.last.id, id);
  });

  testGeotag('Indexed filter updates but does not notify when selected item is updated and moves', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.last.id;
    await root[1]._update((MediaItem item) => item.dateTimeOriginal = DateTime.parse('2021-01-01'));
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[4]);
    expect(selected.last.id, id);
  });

  testGeotag('Indexed filter updates but does not notify when item is inserted', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    root.comparator = const ByDate(Descending());
    await root.addFiles(<String>[
      images.oneByOneBlackJpgWithDateAndGeo,
      images.oneByOneWhite,
      images.oneByOneBlack,
      images.oneByOneBlackJpgWithGeo,
    ]).drain<void>();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    final int id = selected.last.id;
    expect(selected.length, 1);
    await root.addFiles(<String>[images.oneByOneBlackJpgWithDate]).drain<void>();
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[3]);
    expect(selected.last.id, id);
  });

  testGeotag('Indexed filter updates but does not notify when other item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    final int id = selected.last.id;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    await root.where(IndexedMediaItemFilter(<int>[0])).deleteFiles().drain<void>();
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[1]);
    expect(selected.last.id, id);
  });

  testGeotag('Indexed filter updates and notifies when selected item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    await root.where(IndexedMediaItemFilter(<int>[2])).deleteFiles().drain<void>();
    expect(selected.length, 0);
    expect(structureChanged, isTrue);
    expect(filter.indexes, isEmpty);
  });

  testGeotag('Indexed filter updates and notifies when comparator is changed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[4]);
    final MediaItems selected = root.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.first.id;
    root.comparator = const ByDate(Descending());
    expect(selected.length, 1);
    expect(structureChanged, isTrue);
    expect(filter.indexes, <int>[0]);
    expect(selected.first.id, id);
  });

  testGeotag('Predicate->Indexed filter does not update or notify when item is updated and stays in place', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    await tester.pump(const Duration(seconds: 1));
    await root[0]._update((MediaItem item) => item.dateTimeOriginal = tester.binding.clock.now());
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[1]);
  });

  testGeotag('Predicate->Indexed filter updates but does not notify when different item is updated and moves', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.last.id;
    await root[0]._update((MediaItem item) => item.dateTimeOriginal = tester.binding.clock.now());
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[0]);
    expect(selected.last.id, id);
  });

  testGeotag('Predicate->Indexed filter updates but does not notify when selected item is updated and moves', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.last.id;
    await root[1]._update((MediaItem item) => item.dateTimeOriginal = DateTime.parse('2023-01-01'));
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[2]);
    expect(selected.last.id, id);
  });

  testGeotag('Predicate->Indexed filter updates but does not notify when item is inserted', (WidgetTester tester) async {
    final ImageReferences images = tester.loadImages();
    final RootMediaItems root = MediaBinding.instance.items;
    root.comparator = const ByDate(Descending());
    await root.addFiles(<String>[
      images.oneByOneBlackJpgWithDateAndGeo,
      images.oneByOneWhite,
      images.oneByOneBlack,
      images.oneByOneBlackJpgWithGeo,
    ]).drain<void>();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[1]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    final int id = selected.last.id;
    expect(selected.length, 1);
    await root.addFiles(<String>[images.oneByOneBlackJpgWithDate]).drain<void>();
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[2]);
    expect(selected.last.id, id);
  });

  testGeotag('Predicate->Indexed filter updates but does not notify when other item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    final int id = selected.last.id;
    expect(selected.length, 1);
    await root.where(IndexedMediaItemFilter(<int>[0])).deleteFiles().drain<void>();
    expect(selected.length, 1);
    expect(structureChanged, isFalse);
    expect(filter.indexes, <int>[1]);
    expect(selected.last.id, id);
  });

  testGeotag('Predicate->Indexed filter updates and notifies when selected item is removed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    await root.where(IndexedMediaItemFilter(<int>[2])).deleteFiles().drain<void>();
    expect(selected.length, 0);
    expect(structureChanged, isTrue);
    expect(filter.indexes, isEmpty);
  });

  testGeotag('Predicate->Indexed filter updates and notifies when comparator is changed', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    final MediaItems noGeo = root.where(const PredicateMediaItemFilter(_needsGeo));
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2]);
    final MediaItems selected = noGeo.where(filter);
    bool structureChanged = false;
    selected.addStructureListener(() => structureChanged = true);
    expect(selected.length, 1);
    final int id = selected.first.id;
    root.comparator = const ByDate(Descending());
    expect(selected.length, 1);
    expect(structureChanged, isTrue);
    expect(filter.indexes, <int>[0]);
    expect(selected.first.id, id);
  });

  testGeotag('Indexed->Predicate filter updates and notifies when comparator is changed and relative index order changes', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[2, 3]);
    final MediaItems selected = root.where(filter);
    final MediaItems noGeo = selected.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 1);
    final int id = noGeo.first.id;
    root.comparator = const ByDate(Descending());
    expect(noGeo.length, 1);
    expect(structureChanged, isTrue);
    expect(filter.indexes, <int>[1, 2]);
    expect(noGeo.first.id, id);
    root[2].event = 'test event';
    await root[2].commit();
  });

  testGeotag('Indexed->Predicate filter updates and notifies when selected item is updated and moves and relative index order changes', (WidgetTester tester) async {
    final RootMediaItems root = await tester._populateItems();
    root.comparator = const ByDate(Ascending());
    final IndexedMediaItemFilter filter = IndexedMediaItemFilter(<int>[0, 1]);
    final MediaItems selected = root.where(filter);
    final MediaItems noGeo = selected.where(const PredicateMediaItemFilter(_needsGeo));
    bool structureChanged = false;
    noGeo.addStructureListener(() => structureChanged = true);
    expect(noGeo.length, 2);
    final int blackId = noGeo[0].id;
    final int whiteId = noGeo[1].id;
    root[0].dateTimeOriginal = tester.binding.clock.now();
    await root[0].commit();
    expect(noGeo.length, 2);
    expect(structureChanged, isTrue);
    expect(filter.indexes, <int>[0, 2]);
    expect(noGeo[0].id, whiteId);
    expect(noGeo[1].id, blackId);
  });
}
