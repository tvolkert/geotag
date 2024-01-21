// ignore_for_file: avoid_print

import 'dart:async';

import 'package:chicago/chicago.dart' as chicago show binarySearch;
import 'package:collection/collection.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geotag/src/extensions/iterable.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

import '../foundation/base.dart';
import 'app.dart';
import 'db.dart';
import 'gps.dart';
import 'files.dart';
import 'image.dart';
import 'isolates.dart';
import 'metadata.dart';
import 'video.dart';

/// The types of media that are supported by the Geotagger app.
enum MediaType {
  /// A still photo.
  ///
  /// Current supported types are JPG.
  photo,

  /// A video.
  ///
  /// Current supported types are MP4.
  video,
}

/// A media file that can be associated with a date/time and a geo-location.
///
/// The types of media that are supported are enumerated in [MediaType].
///
/// Listeners can register to be notified when properties of a media item
/// change by calling [MediaBinding.addItemListener].
class MediaItem {
  /// Creates a new [MediaItem] with no metadata.
  MediaItem._empty() : _row = DbRow(), _unsavedRow = DbRow();

  /// Creates a new [MediaItem] from the specified database row.
  ///
  /// The [row] will be used directly as the backing data structure for this
  /// newly created item, so changes to the row will be reflected in this
  /// item.
  MediaItem.fromDbRow(DbRow row) : _row = row, _unsavedRow = DbRow.from(row);

  final DbRow _row;
  final DbRow _unsavedRow;

  /// The unique id of this media item.
  ///
  /// IDs are assigned by the database and are ever increasing, so a greater
  /// ID means that the item was inserted into the database later.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  int get id => _row['ITEM_ID'] as int;
  set id(int value) => _unsavedRow['ITEM_ID'] = value;

  /// The type of this media item.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  MediaType get type => MediaType.values[_row['TYPE'] as int];
  set type(MediaType value) => _unsavedRow['TYPE'] = value.index;

  /// The file system path to this media item.
  ///
  /// This path can be resolved to a file by using [FilesBinding.fs]
  ///
  /// This value will be unique across all media items, and as such, it is used
  /// as the key to methods like [MediaBinding.addItemListener].
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  String get path => _row['PATH'] as String;
  set path(String value) => _unsavedRow['PATH'] = value;

  /// The file system path to the photo representation of this media item.
  ///
  /// For photos, this will be the same as [path]. For videos, a photo
  /// representation of the video will be generated when the video is imported.
  ///
  /// This path can be resolved to a file by using [FilesBinding.fs]
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  String get photoPath => _row['PHOTO_PATH'] as String;
  set photoPath(String value) => _unsavedRow['PHOTO_PATH'] = value;

  /// JPEG-encoded bytes of a small thumbnail representation of this media
  /// item.
  ///
  /// These bytes are suitable to be used in the [Image.memory] widget.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  ///
  /// See also:
  ///
  ///  * [JpegFile.getThumbnailBytes], which is used to extract the bytes for a
  ///    thumbnail version of a JPEG image.
  ///  * [Mp4.getFrameBytes], which is used to extract the bytes for a thumbnail
  ///    version of an MPEG-4 video.
  Uint8List get thumbnail => _row['THUMBNAIL'] as Uint8List;
  set thumbnail(Uint8List value) => _unsavedRow['THUMBNAIL'] = value;

  /// Whether this media item has geo-location information attached to it.
  bool get hasLatlng => _row['LATLNG'] != null;

  /// The geo-location information associated with this media item, if any.
  ///
  /// This value, if set, is a comma-separated string containing a latitude
  /// and longitude. This string value is suitable for use with the
  /// [GpsCoordinates.fromString] constructor.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  String? get latlng => _row['LATLNG'] as String?;
  set latlng(String? value) {
    assert(value == null || RegExp(r'^-?[0-9]+\.?[0-9]*, *-?[0-9]+\.?[0-9]*$').hasMatch(value));
    _unsavedRow['LATLNG'] = value;
  }

  /// Whether this media item has an "original date/time" value attached to it.
  ///
  /// The "original date/time" value is the timestamp of when the media item
  /// was orignally created, even if it was not digitized until later. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  ///
  /// See also:
  ///
  ///  * [hasDateTimeDigitized], which tells whether or not the media item has
  ///    a "date/time digitized" value attached to it.
  bool get hasDateTimeOriginal => _row['DATETIME_ORIGINAL'] != null;

  /// The "original date/time" value associated with this media item, if any.
  ///
  /// The "original date/time" value is the timestamp of when the media item
  /// was orignally created, even if it was not digitized until later. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  ///
  /// See also:
  ///
  ///  * [dateTimeDigitized], which is the date/time that the media item was
  ///    first digitized.
  DateTime? get dateTimeOriginal {
    return hasDateTimeOriginal
        ? DateTime.fromMillisecondsSinceEpoch(_row['DATETIME_ORIGINAL'] as int)
        : null;
  }

  set dateTimeOriginal(DateTime? value) {
    _unsavedRow['DATETIME_ORIGINAL'] = value?.millisecondsSinceEpoch;
  }

  /// Whether this media item has an "date/time digitized" value attached to
  /// it.
  ///
  /// The "date/time digitized" value is the timestamp of when the media item
  /// was orignally digitized, even if it was created before that time. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  ///
  /// See also:
  ///
  ///  * [hasDateTimeOriginal], which tells whether or not the media item has
  ///    a "original date/time" value attached to it.
  bool get hasDateTimeDigitized => _row['DATETIME_DIGITIZED'] != null;

  /// The "date/time digitized" value associated with this media item, if any.
  ///
  /// The "date/time digitized" value is the timestamp of when the media item
  /// was orignally digitized, even if it was created before that time. An
  /// example is a photo taken with a film camera, which was taken at one point
  /// in time but later digitized into an encoded file.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  ///
  /// See also:
  ///
  ///  * [dateTimeOriginal], which is the date/time that the media item was
  ///    originally created.
  DateTime? get dateTimeDigitized {
    return hasDateTimeDigitized
        ? DateTime.fromMillisecondsSinceEpoch(_row['DATETIME_DIGITIZED'] as int)
        : null;
  }

  set dateTimeDigitized(DateTime? value) {
    _unsavedRow['DATETIME_DIGITIZED'] = value?.millisecondsSinceEpoch;
  }

  /// whether this media item has any date/time attached to it.
  bool get hasDateTime => hasDateTimeOriginal || hasDateTimeDigitized;

  /// The preferred date/time associated with this media item, if any.
  ///
  /// This will be the [dateTimeOriginal] if it's set, otherwise the
  /// [dateTimeDigitized].
  DateTime? get dateTime => dateTimeOriginal ?? dateTimeDigitized;

  /// The coordinates attached to this media item, if any.
  ///
  /// See also:
  ///
  ///  * [latlng], which is the raw value from which this coordinates object
  ///    is created.
  GpsCoordinates? get coords => hasLatlng ? GpsCoordinates.fromString(latlng!) : null;

  /// Whether edits have been made to this media item's metadata but not yet
  /// written to the media item's file.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  bool get isModified => _row['MODIFIED'] == 1;
  set isModified(bool value) => _unsavedRow['MODIFIED'] = value ? 1 : 0;

  /// The date/time that edits were last made to this media item's metadata.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  DateTime get lastModified {
    return DateTime.fromMillisecondsSinceEpoch(_row['DATETIME_LAST_MODIFIED'] as int);
  }

  set lastModified(DateTime value) {
    _unsavedRow['DATETIME_LAST_MODIFIED'] = value.millisecondsSinceEpoch;
  }

  /// Writes this media item's metadata fields to the database and notifies
  /// listeners that the metadata has changed.
  Future<void> commit() async {
    final RootMediaItems items = MediaBinding.instance.items;
    final int oldIndex = items.indexOf(this);
    await _writeToDb(DatabaseBinding.instance.db);
    _persistAndNotify();
    if (oldIndex >= 0) {
      // The edits have caused this item to be in a different position in the
      // [MediaItems] list.
      items._removeAndReinsertFrom(oldIndex);
    }
  }

  Future<void> _writeToDb(sqflite.Database db) {
    return db.update(
      'MEDIA',
      <String, Object?>{
        'LATLNG': _unsavedRow['LATLNG'],
        'DATETIME_ORIGINAL': _unsavedRow['DATETIME_ORIGINAL'],
        'DATETIME_DIGITIZED': _unsavedRow['DATETIME_DIGITIZED'],
        'MODIFIED': _unsavedRow['MODIFIED'],
        'DATETIME_LAST_MODIFIED': _unsavedRow['DATETIME_LAST_MODIFIED'],
      },
      where: 'PATH = ?',
      whereArgs: <String>[path],
    );
  }

  void _persistAndNotify() {
    _row.addAll(_unsavedRow);
    MediaBinding.instance._notifyPhotoChanged(path);
  }

  @override
  String toString() {
    return '<MediaItem(type=$type, id=$id, path=$path)>';
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    return other is MediaItem && other.id == id;
  }
}

sealed class SortDirection {
  const SortDirection();

  int apply(int comparedValue);

  SortDirection get reversed {
    switch (this) {
      case Ascending():
        return const Descending();
      case Descending():
        return const Ascending();
    }
  }

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class Ascending extends SortDirection {
  const Ascending();

  @override
  int apply(int comparedValue) => comparedValue;
}

final class Descending extends SortDirection {
  const Descending();

  @override
  int apply(int comparedValue) => comparedValue * -1;
}

sealed class MediaItemComparator {
  const MediaItemComparator(this.direction);

  final SortDirection direction;

  @nonVirtual
  int compare(MediaItem a, MediaItem b) => direction.apply(doCompare(a, b));

  /// Compares two media items.
  ///
  /// Returns -1, 0, or 1 if item [a] is less than, equal to, or greater than
  /// item [b], respectively.
  ///
  /// Subclasses are only ever allowed to return 0 if [a] and [b] are
  /// represented by the same [MediaItem.id]; otherwise, comparators must
  /// find a way to break the equality.
  @protected
  int doCompare(MediaItem a, MediaItem b);

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        direction == (other as MediaItemComparator).direction;
  }

  @override
  int get hashCode => Object.hash(runtimeType.hashCode, direction.hashCode);
}

final class ById extends MediaItemComparator {
  const ById(super.direction);

  @override
  @protected
  int doCompare(MediaItem a, MediaItem b) => a.id.compareTo(b.id);
}

final class ByDate extends MediaItemComparator {
  const ByDate(super.direction);

  static const ById _byId = ById(Ascending());

  @override
  @protected
  int doCompare(MediaItem a, MediaItem b) {
    if (a.dateTime == null && b.dateTime == null) {
      return _byId.compare(a, b);
    } else if (a.dateTime == null) {
      return -1;
    } else if (b.dateTime == null) {
      return 1;
    } else {
      final int result = a.dateTime!.compareTo(b.dateTime!);
      return result != 0 ? result : _byId.compare(a, b);
    }
  }
}

base class MediaItemsView {
  MediaItemsView._(this._items);

  MediaItemsView.empty() : _items = <MediaItem>[];

  MediaItemsView.from(Iterable<MediaItem> items) : _items = List<MediaItem>.from(items);

  final List<MediaItem> _items;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  MediaItem get first => _items.first;

  bool get isSingle => _items.isSingle;

  MediaItem get single => _items.single;

  MediaItem? get singleOrNull => _items.singleOrNull;

  int get length => _items.length;

  MediaItem operator [](int index) => _items[index];

  Iterable<T> map<T>(T Function(MediaItem item) toElement) => _items.map<T>(toElement);

  void forEach(void Function(MediaItem item) action) => _items.forEach(action);
}

abstract base class MediaItems extends MediaItemsView {
  MediaItems._(List<MediaItem> items) : super._(items);

  int _generation = 1;

  RootMediaItems get root => MediaBinding.instance.items;

  MediaItemComparator get comparator;
  set comparator(MediaItemComparator value);

  bool get containsModified => _items.where((MediaItem item) => item.isModified).isNotEmpty;

  static bool _isModified(MediaItem item) => item.isModified;

  MediaItems get whereModified => where(const PredicateMediaItemFilter(_isModified));

  MediaItems where(MediaItemFilter filter) => FilteredMediaItems(filter, this);

  int indexOf(MediaItem item) {
    final int index = chicago.binarySearch(_items, item, compare: comparator.compare);
    return index < 0 ? -1 : index;
  }

  Stream<void> writeFilesToDisk() {
    // TODO: provide hook whereby caller can cancel operation.
    final List<MediaItem> localItems = List<MediaItem>.from(_items);
    final _WriteToDiskMessage message = _WriteToDiskMessage._(
      DatabaseBinding.instance.dbFile.absolute.path,
      localItems,
    );
    final Stream<int> iter = Isolates.stream<_WriteToDiskMessage, int>(
      _writeToDiskWorker,
      message,
      debugLabel: 'writeFilesToDisk',
    );
    final StreamController<void> controller = StreamController<void>();
    iter.listen((int i) {
      // The changes have already been written to disk and saved to the
      // database, but the changes were done in a separate isolate, so the
      // local row object in this isolate needs to be updated to match.
      localItems[i]
        ..isModified = false
        .._persistAndNotify();
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  Stream<void> deleteFiles() {
    // TODO: provide hook whereby caller can cancel operation.
    final List<MediaItem> localItems = List<MediaItem>.from(_items);
    final _DeleteFilesMessage message = _DeleteFilesMessage._(
      DatabaseBinding.instance.dbFile.absolute.path,
      localItems,
    );
    final Stream<int> iter = Isolates.stream<_DeleteFilesMessage, int>(
      _deleteFilesWorker,
      message,
      debugLabel: 'deleteFiles',
    );
    final StreamController<void> controller = StreamController<void>();
    iter.listen((int i) {
      // The database has already been updated, and the file has been deleted
      // from the file system, but the changes were done in a separate isolate,
      // so the items list needs to be updated to match.
      final MediaItem removed = localItems[i];
      root._removeAt(root.indexOf(removed));
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  Stream<void> exportToFolder(String folder) {
    final _ExportToFolderMessage message = _ExportToFolderMessage._(
      folder,
      List<MediaItem>.from(_items),
    );
    final Stream<DbRow> iter = Isolates.stream<_ExportToFolderMessage, DbRow>(
      _exportToFolderWorker,
      message,
      debugLabel: 'exportToFolder',
    );
    final StreamController<void> controller = StreamController<void>();
    iter.listen((DbRow row) {
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  static Stream<int> _writeToDiskWorker(_WriteToDiskMessage message) async* {
    sqflite.databaseFactory = sqflite.databaseFactoryFfi;
    final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
    for (int i = 0; i < message.items.length; i++) {
      try {
        final MediaItem item = message.items[i];
        switch (item.type) {
          case MediaType.photo:
            final JpegFile jpeg = JpegFile(item.path);
            bool needsWrite = false;
            if (item.hasDateTimeOriginal) {
              needsWrite = true;
              jpeg.setDateTimeOriginal(item.dateTimeOriginal!);
            }
            if (item.hasDateTimeDigitized) {
              needsWrite = true;
              jpeg.setDateTimeDigitized(item.dateTimeDigitized!);
            }
            if (item.hasLatlng) {
              needsWrite = true;
              jpeg.setGpsCoordinates(GpsCoordinates.fromString(item.latlng!));
            }
            if (needsWrite) {
              jpeg.write();
            }
          case MediaType.video:
            final Mp4 mp4 = Mp4(item.path);
            await mp4.writeMetadata(dateTime: item.dateTime, coordinates: item.coords);
        }
        item.isModified = false;
        await item._writeToDb(db);
        yield i;
      } catch (error, stack) {
        yield* Stream<int>.error(error, stack);
      }
    }
  }

  static Stream<int> _deleteFilesWorker(_DeleteFilesMessage message) async* {
    sqflite.databaseFactory = sqflite.databaseFactoryFfi;
    final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
    const FileSystem fs = LocalFileSystem();
    // Traverse the list backwards so that our stream of indexes will be valid
    // even as we remove items from the list.
    for (int i = message.items.length - 1; i >= 0; i--) {
      try {
        final MediaItem item = message.items[i];
        fs.file(item.path).deleteSync();
        if (item.path != item.photoPath) {
          fs.file(item.photoPath).deleteSync();
        }
        await db.delete('MEDIA', where: 'PATH = ?', whereArgs: [item.path]);
        yield i;
      } catch (error, stack) {
        yield* Stream<int>.error(error, stack);
      }
    }
  }

  static Stream<DbRow> _exportToFolderWorker(_ExportToFolderMessage message) async* {
    const FileSystem fs = LocalFileSystem();
    final Directory root = fs.directory(message.folder);
    assert(root.existsSync());
    for (MediaItem item in message.items) {
      try {
        final int year = item.hasDateTime ? item.dateTime!.year : 0;
        final Directory parent = root.childDirectory(year.toString().padLeft(4, '0'));
        if (!parent.existsSync()) {
          parent.createSync();
        }
        final String path = item.path;
        final String basename = fs.file(path).basename;
        File target = parent.childFile(basename);
        for (int i = 1; target.existsSync(); i++) {
          // Resolve collision
          target = parent.childFile('$basename ($i)');
        }
        // https://github.com/flutter/flutter/issues/140763
        await fs.file(path).copy(target.path);
        yield item._row;
      } catch (error, stack) {
        yield* Stream<DbRow>.error(error, stack);
      }
    }
  }
}

final class EmptyMediaItems extends MediaItems {
  EmptyMediaItems() : super._(<MediaItem>[]);

  @override
  MediaItemComparator get comparator => const ById(Ascending());

  @override
  set comparator(MediaItemComparator value) => throw UnsupportedError('comparator=');

  @override
  Stream<void> writeFilesToDisk() => throw UnsupportedError('writeFilesToDisk');

  @override
  Stream<void> deleteFiles() => throw UnsupportedError('deleteFiles');

  @override
  Stream<void> exportToFolder(String folder) => throw UnsupportedError('exportToFolder');
}

final class RootMediaItems extends MediaItems {
  RootMediaItems.fromDbResults(DbResults results) : _comparator = const ById(Ascending()), super._(
    List<MediaItem>.generate(results.length, (int index) {
      return MediaItem.fromDbRow(results[index]);
    }),
  );

  _MediaNotifier? _notifier;
  MediaItemComparator _comparator;

  @override
  RootMediaItems get root => this;

  void addListener(VoidCallback listener) {
    _notifier ??= _MediaNotifier();
    _notifier!.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    assert(_notifier != null);
    _notifier!.removeListener(listener);
    if (!_notifier!.hasListeners) {
      _notifier!.dispose();
      _notifier = null;
    }
  }

  void _removeAndReinsertFrom(int index) {
    assert(index >= 0);
    final MediaItem item = _items.removeAt(index);
    int newIndex = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
    assert(newIndex < 0);
    newIndex = -newIndex - 1;
    _items.insert(newIndex, item);
    _generation++;
    if (index != newIndex) {
      _notify();
    }
  }

  void _notify() {
    _notifier?.notifyListeners();
  }

  MediaItem _removeAt(int index) {
    assert(index >= 0);
    final MediaItem removed = _items.removeAt(index);
    _generation++;
    _notify();
    return removed;
  }

  @override
  MediaItemComparator get comparator => _comparator;

  @override
  set comparator(MediaItemComparator value) {
    if (value != _comparator) {
      _comparator = value;
      _items.sort(value.compare);
      _generation++;
      _notify();
    }
  }

  Stream<void> addFiles(Iterable<String> paths) {
    final Directory appSupportDir = FilesBinding.instance.applicationSupportDirectory;
    final _AddFilesMessage message = _AddFilesMessage._(
      DatabaseBinding.instance.dbFile.absolute.path,
      appSupportDir.absolute.path,
      paths,
    );
    final Stream<DbRow> rows = Isolates.stream<_AddFilesMessage, DbRow>(
      _addFilesWorker,
      message,
      debugLabel: 'addFiles',
    );
    final StreamController<void> controller = StreamController<void>();
    rows.listen((DbRow row) {
      final MediaItem item = MediaItem.fromDbRow(row);
      final int index = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
      assert(index < 0);
      _items.insert(-index - 1, item);
      _generation++;
      _notify();
      assert(() {
        final List<MediaItem> copy = List<MediaItem>.from(_items)..sort(_comparator.compare);
        return const ListEquality<MediaItem>().equals(_items, copy);
      }());
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  /// This runs in a separate isolate.
  static Stream<DbRow> _addFilesWorker(_AddFilesMessage message) async* {
    const FileSystem fs = LocalFileSystem();
    sqflite.databaseFactory = sqflite.databaseFactoryFfi;
    final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
    final ChrootFileSystem chrootFs = ChrootFileSystem(
      fs,
      fs.path.join(message.appSupportPath, 'media'),
    );
    for (String path in message.paths) {
      try {
        final String extension = path.split('.').last.toLowerCase();
        final Uint8List bytes = fs.file(path).readAsBytesSync();
        chrootFs.file(path).parent.createSync(recursive: true);
        chrootFs.file(path).writeAsBytesSync(bytes);
        final String chrootPath = '${chrootFs.root}$path';
        assert(fs.file(chrootPath).existsSync());
        assert(const ListEquality<int>().equals(
          fs.file(path).readAsBytesSync(),
          chrootFs.file(path).readAsBytesSync(),
        ));

        Future<DbRow> insertRow(Metadata metadata, MediaType type) async {
          MediaItem item = MediaItem._empty()
            ..type = type
            ..path = chrootPath
            ..photoPath = '${chrootFs.root}${metadata.photoPath}'
            ..thumbnail = metadata.thumbnail
            ..latlng = metadata.coordinates?.latlng
            ..dateTimeOriginal = metadata.dateTimeOriginal
            ..dateTimeDigitized = metadata.dateTimeDigitized
            ..lastModified = DateTime.now()
            ..isModified = false;
          item.id = await db.insert('MEDIA', item._unsavedRow);
          return item._unsavedRow;
        }

        if (JpegFile.allowedExtensions.contains(extension)) {
          final JpegFile jpeg = JpegFile(path);
          final Metadata metadata = jpeg.extractMetadata();
          yield await insertRow(metadata, MediaType.photo);
        } else if (Mp4.allowedExtensions.contains(extension)) {
          final Mp4 mp4 = Mp4(path);
          final Metadata metadata = mp4.extractMetadata(chrootFs);
          yield await insertRow(metadata, MediaType.video);
        } else {
          yield* Stream<DbRow>.error(UnsupportedError('Unsupported file: $path'));
        }
      } catch (error, stack) {
        if (chrootFs.file(path).existsSync()) {
          chrootFs.file(path).deleteSync();
        }
        yield* Stream<DbRow>.error(error, stack);
      }
    }
  }
}

abstract base class MediaItemFilter {
  const MediaItemFilter();

  Iterable<MediaItem> apply(List<MediaItem> source);
}

final class PredicateMediaItemFilter extends MediaItemFilter {
  const PredicateMediaItemFilter(this.condition);

  final Predicate<MediaItem> condition;

  @override
  Iterable<MediaItem> apply(List<MediaItem> source) => source.where(condition);
}

final class IndexedMediaItemFilter extends MediaItemFilter {
  const IndexedMediaItemFilter(this.indexes);

  final Iterable<int> indexes;

  @override
  Iterable<MediaItem> apply(List<MediaItem> source) {
    final List<MediaItem> result = <MediaItem>[];
    for (int index in indexes) {
      result.add(source[index]);
    }
    return result;
  }
}

final class FilteredMediaItems extends MediaItems {
  FilteredMediaItems(this.filter, this.parent) : super._(<MediaItem>[]) {
    _debugAssertChainToRoot();
    _updateItems();
  }

  final MediaItems parent;
  final MediaItemFilter filter;

  void _debugAssertChainToRoot() {
    assert(() {
      MediaItems root = parent;
      while (root is FilteredMediaItems) {
        root = root.parent;
      }
      return root == MediaBinding.instance.items;
    }());
  }

  @override
  RootMediaItems get root {
    _debugAssertChainToRoot();
    return MediaBinding.instance.items;
  }

  @override
  List<MediaItem> get _items {
    if (_generation != parent._generation) {
      _updateItems();
    }
    return super._items;
  }

  void _updateItems() {
    super._items..clear()..addAll(filter.apply(parent._items));
    _generation = parent._generation;
  }

  @override
  MediaItemComparator get comparator => parent.comparator;

  @override
  set comparator(MediaItemComparator value) => parent.comparator = value;
}

class _AddFilesMessage {
  const _AddFilesMessage._(this.dbPath, this.appSupportPath, this.paths);

  final String dbPath;
  final String appSupportPath;
  final Iterable<String> paths;
}

class _WriteToDiskMessage {
  const _WriteToDiskMessage._(this.dbPath, this.items);

  final String dbPath;
  final List<MediaItem> items;
}

class _DeleteFilesMessage {
  const _DeleteFilesMessage._(this.dbPath, this.items);

  final String dbPath;
  final List<MediaItem> items;
}

class _ExportToFolderMessage {
  const _ExportToFolderMessage._(this.folder, this.items);

  final String folder;
  final List<MediaItem> items;
}

mixin MediaBinding on AppBindingBase, DatabaseBinding {
  /// The singleton instance of this object.
  static late MediaBinding _instance;
  static MediaBinding get instance => _instance;

  // TODO: change to be keyed off ITEM_ID instead of PATH
  final Map<String, _MediaNotifier> _itemNotifiers = <String, _MediaNotifier>{};

  late RootMediaItems _items;
  RootMediaItems get items => _items;

  void addItemListener(String path, VoidCallback listener) {
    final _MediaNotifier notifier = _itemNotifiers.putIfAbsent(path, () => _MediaNotifier());
    notifier.addListener(listener);
  }

  void removeItemListener(String path, VoidCallback listener) {
    final _MediaNotifier? notifier = _itemNotifiers[path];
    assert(notifier != null);
    notifier!.removeListener(listener);
    if (!notifier.hasListeners) {
      notifier.dispose();
      _itemNotifiers.remove(path);
    }
  }

  void _notifyPhotoChanged(String path) {
    _itemNotifiers[path]?.notifyListeners();
  }

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    final DbResults results = await getAllMediaItems();
    _items = RootMediaItems.fromDbResults(results);
    _instance = this;
  }
}

class _MediaNotifier extends Object with ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();

  @override
  bool get hasListeners => super.hasListeners;
}
