// ignore_for_file: avoid_print

import 'package:chicago/chicago.dart' as chicago show binarySearch;
import 'package:collection/collection.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

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
  MediaItem._empty() : _row = DbRow();

  /// Creates a new [MediaItem] from the specified database row.
  MediaItem.fromDbRow(DbRow row) : _row = row;

  final DbRow _row;

  /// The unique id of this media item.
  ///
  /// IDs are assigned by the database and are ever increasing, so a greater
  /// ID means that the item was inserted into the database later.
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  int get id => _row['ITEM_ID'] as int;
  set id(int value) => _row['ITEM_ID'] = value;

  /// The type of this media item.
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  MediaType get type => MediaType.values[_row['TYPE'] as int];
  set type(MediaType value) => _row['TYPE'] = value.index;

  /// The file system path to this media item.
  ///
  /// This path can be resolved to a file by using [FilesBinding.fs]
  ///
  /// This value will be unique across all media items, and as such, it is used
  /// as the key to methods like [MediaBinding.addItemListener].
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  String get path => _row['PATH'] as String;
  set path(String value) => _row['PATH'] = value;

  /// The file system path to the photo representation of this media item.
  ///
  /// For photos, this will be the same as [path]. For videos, a photo
  /// representation of the video will be generated when the video is imported.
  ///
  /// This path can be resolved to a file by using [FilesBinding.fs]
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  String get photoPath => _row['PHOTO_PATH'] as String;
  set photoPath(String value) => _row['PHOTO_PATH'] = value;

  /// JPEG-encoded bytes of a small thumbnail representation of this media
  /// item.
  ///
  /// These bytes are suitable to be used in the [Image.memory] widget.
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  Uint8List get thumbnail => _row['THUMBNAIL'] as Uint8List;
  set thumbnail(Uint8List value) => _row['THUMBNAIL'] = value;

  /// Whether this media item has geo-location information attached to it.
  bool get hasLatlng => _row['LATLNG'] != null;

  /// The geo-location information associated with this media item, if any.
  ///
  /// This value, if set, is a comma-separated string containing a latitude
  /// and longitude. This string value is suitable for use with the
  /// [GpsCoordinates.fromString] constructor.
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  String? get latlng => _row['LATLNG'] as String?;
  set latlng(String? value) {
    assert(value == null || RegExp(r'^-?[0-9]+\.?[0-9]*, *-?[0-9]+\.?[0-9]*$').hasMatch(value));
    _row['LATLNG'] = value;
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
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
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
    _row['DATETIME_ORIGINAL'] = value?.millisecondsSinceEpoch;
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
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
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
    _row['DATETIME_DIGITIZED'] = value?.millisecondsSinceEpoch;
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
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  bool get isModified => _row['MODIFIED'] == 1;
  set isModified(bool value) => _row['MODIFIED'] = value ? 1 : 0;

  /// The date/time that edits were last made to this media item's metadata.
  ///
  /// Listeners will not be notified when this value is changed until [commit]
  /// is called.
  DateTime get lastModified {
    return DateTime.fromMillisecondsSinceEpoch(_row['DATETIME_LAST_MODIFIED'] as int);
  }

  set lastModified(DateTime value) {
    _row['DATETIME_LAST_MODIFIED'] = value.millisecondsSinceEpoch;
  }

  /// Writes this media item's metadata fields to the database and notifies
  /// listeners that the metadata has changed.
  Future<void> commit() async {
    await _writeToDb(DatabaseBinding.instance.db);
    _notify();
  }

  Future<void> _writeToDb(sqflite.Database db) {
    return db.update(
      'MEDIA',
      <String, Object?>{
        'LATLNG': _row['LATLNG'],
        'DATETIME_ORIGINAL': _row['DATETIME_ORIGINAL'],
        'DATETIME_DIGITIZED': _row['DATETIME_DIGITIZED'],
        'MODIFIED': _row['MODIFIED'],
        'DATETIME_LAST_MODIFIED': _row['DATETIME_LAST_MODIFIED'],
      },
      where: 'PATH = ?',
      whereArgs: <String>[path],
    );
  }

  void _notify() {
    MediaBinding.instance._notifyPhotoChanged(path);
  }

  @override
  String toString() {
    return '<MediaItem(type=$type, path=$path)>';
  }

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) {
    return other is MediaItem && other.path == path;
  }
}

class _FilteredItems {
  const _FilteredItems(this.items, this.lookup);

  /// The filtered items, guaranteed to be a subset of [MediaItems._items]
  final List<MediaItem> items;

  /// Maps [MediaItem.path] to the index of the item in [MediaItems._items].
  final Map<String, int> lookup;

  int getOriginalIndex(int filteredIndex) {
    final String path = items[filteredIndex].path;
    return lookup[path]!;
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

  @override
  @protected
  int doCompare(MediaItem a, MediaItem b) {
    if (a.dateTime == null && b.dateTime == null) {
      return 0;
    } else if (a.dateTime == null) {
      return -1;
    } else if (b.dateTime == null) {
      return 1;
    } else {
      return a.dateTime!.compareTo(b.dateTime!);
    }
  }
}

class MediaItems {
  MediaItems._from(this._items, this._comparator);

  MediaItems.fromDbResults(DbResults results)
      : _comparator = const ById(Ascending()),
        _items = List<MediaItem>.generate(results.length, (int index) {
          return MediaItem.fromDbRow(results[index]);
        });

  MediaItemComparator _comparator;
  final List<MediaItem> _items;

  MediaItemComparator get comparator => _comparator;
  set comparator(MediaItemComparator value) {
    if (value != _comparator) {
      _comparator = value;
      _items.sort(value.compare);
      MediaBinding.instance._notifyCollectionChanged();
    }
  }

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get length => _items.length;

  bool get containsModified => _items.where((MediaItem item) => item.isModified).isNotEmpty;

  MediaItems get whereModified {
    return MediaItems._from(_items.where((MediaItem item) => item.isModified).toList(), comparator);
  }

  int indexOfId(int id) => _items.indexWhere((MediaItem item) => item.id == id);

  MediaItem operator [](int index) => _items[index];

  Stream<MediaItem> addFiles(Iterable<String> paths) async* {
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
    await for (final DbRow row in rows) {
      final MediaItem item = MediaItem.fromDbRow(row);
      final int index = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
      assert(index < 0);
      _items.insert(-index - 1, item);
      assert(() {
        final List<MediaItem> copy = List<MediaItem>.from(_items)..sort(_comparator.compare);
        return const ListEquality<MediaItem>().equals(_items, copy);
      }());
      yield item;
      MediaBinding.instance._notifyCollectionChanged();
    }
  }

  Stream<MediaItem> writeFilesToDisk() async* {
    // TODO: provide hook whereby caller can cancel operation.
    final _WriteToDiskMessage message = _WriteToDiskMessage._(
      DatabaseBinding.instance.dbFile.absolute.path,
      List<MediaItem>.from(_items),
    );
    final Stream<int> iter = Isolates.stream<_WriteToDiskMessage, int>(
      _writeToDiskWorker,
      message,
      debugLabel: 'writeFilesToDisk',
    );
    await for (final int i in iter) {
      // The changes have already been written to disk and saved to the
      // database, but the changes were done in a separate isolate, so the
      // local row object in this isolate needs to be updated to match.
      _items[i]
        ..isModified = false
        .._notify();
      yield _items[i];
    }
  }

  Stream<MediaItem> deleteFiles(Iterable<int> indexes) async* {
    // TODO: provide hook whereby caller can cancel operation.
    final _FilteredItems filtered = _filterItems(indexes);
    final _DeleteFilesMessage message = _DeleteFilesMessage._(
      DatabaseBinding.instance.dbFile.absolute.path,
      filtered.items,
    );
    final Stream<int> iter = Isolates.stream<_DeleteFilesMessage, int>(
      _deleteFilesWorker,
      message,
      debugLabel: 'deleteFiles',
    );
    await for (final int filteredIndex in iter) {
      final int index = filtered.getOriginalIndex(filteredIndex);
      final MediaItem removed = _items.removeAt(index);
      assert(removed.path == filtered.items[filteredIndex].path);
      yield removed;
      MediaBinding.instance._notifyCollectionChanged();
    }
  }

  Stream<void> exportToFolder(String folder, Iterable<int> indexes) async* {
    final _FilteredItems filtered = _filterItems(indexes);
    final _ExportToFolderMessage message = _ExportToFolderMessage._(
      folder,
      filtered.items,
    );
    final Stream<DbRow> iter = Isolates.stream<_ExportToFolderMessage, DbRow>(
      _exportToFolderWorker,
      message,
      debugLabel: 'exportToFolder',
    );
    await for (final DbRow _ in iter) {
      yield null;
    }
  }

  _FilteredItems _filterItems(Iterable<int> indexes) {
    assert(indexes.length <= _items.length);
    assert(indexes.every((int index) => index < _items.length));
    Map<String, int> lookup = <String, int>{};
    List<MediaItem> filtered = List<MediaItem>.empty(growable: true);
    for (int i in indexes) {
      filtered.add(_items[i]);
      lookup[_items[i].path] = i;
    }
    return _FilteredItems(filtered, lookup);
  }

  /// This runs in a separate isolate.
  Stream<DbRow> _addFilesWorker(_AddFilesMessage message) async* {
    try {
      const FileSystem fs = LocalFileSystem();
      sqflite.databaseFactory = sqflite.databaseFactoryFfi;
      final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
      final ChrootFileSystem chrootFs = ChrootFileSystem(
        fs,
        fs.path.join(message.appSupportPath, 'media'),
      );
      for (String path in message.paths) {
        final String extension = path.toLowerCase().split('.').last;
        final Uint8List bytes = fs.file(path).readAsBytesSync();
        chrootFs.file(path).parent.createSync(recursive: true);
        chrootFs.file(path).writeAsBytesSync(bytes);
        final String chrootPath = '${chrootFs.root}$path';
        assert(fs.file(chrootPath).existsSync());
        assert(const ListEquality<int>().equals(
          fs.file(path).readAsBytesSync(),
          chrootFs.file(path).readAsBytesSync(),
        ));

        if (JpegFile.allowedExtensions.contains(extension)) {
          final JpegFile jpeg = JpegFile(path);
          final GpsCoordinates? coords = jpeg.getGpsCoordinates();
          final DateTime? dateTimeOriginal = jpeg.getDateTimeOriginal();
          final DateTime? dateTimeDigitized = jpeg.getDateTimeDigitized();
          MediaItem item = MediaItem._empty()
            ..type = MediaType.photo
            ..path = chrootPath
            ..photoPath = chrootPath
            ..thumbnail = jpeg.bytes
            ..latlng = coords?.latlng
            ..dateTimeOriginal = dateTimeOriginal
            ..dateTimeDigitized = dateTimeDigitized
            ..lastModified = DateTime.now()
            ..isModified = false;
          item.id = await db.insert('MEDIA', item._row);
          yield item._row;
        } else if (Mp4.allowedExtensions.contains(extension)) {
          final Mp4 mp4 = Mp4(path);
          final Metadata metadata = mp4.extractMetadata();
          final String extractedFramePath = '$path.jpg';
          mp4.extractFrame(chrootFs, extractedFramePath);
          MediaItem item = MediaItem._empty()
            ..type = MediaType.video
            ..path = chrootPath
            ..photoPath = '${chrootFs.root}$extractedFramePath'
            ..thumbnail = metadata.thumbnail
            ..latlng = metadata.coordinates?.latlng
            ..dateTimeOriginal = metadata.dateTime
            ..dateTimeDigitized = metadata.dateTime
            ..lastModified = DateTime.now()
            ..isModified = false;
          item.id = await db.insert('MEDIA', item._row);
          yield item._row;
        } else {
          yield* _yieldError(UnsupportedError('Unsupported file: $path'));
        }
      }
    } catch (error, stack) {
      print('$error\n$stack');
      yield* _yieldError(error);
    }
  }

  Stream<int> _writeToDiskWorker(_WriteToDiskMessage message) async* {
    try {
      sqflite.databaseFactory = sqflite.databaseFactoryFfi;
      final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
      for (int i = 0; i < message.items.length; i++) {
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
      }
    } catch (error, stack) {
      print('$error\n$stack');
      yield* _yieldError(error);
    }
  }

  Stream<int> _deleteFilesWorker(_DeleteFilesMessage message) async* {
    try {
      sqflite.databaseFactory = sqflite.databaseFactoryFfi;
      final sqflite.Database db = await sqflite.openDatabase(message.dbPath);
      const FileSystem fs = LocalFileSystem();
      // Traverse the list backwards so that our stream of indexes will be valid
      // even as we remove items from the list.
      for (int i = message.items.length - 1; i >= 0; i--) {
        final MediaItem item = message.items[i];
        fs.file(item.path).deleteSync();
        if (item.path != item.photoPath) {
          fs.file(item.photoPath).deleteSync();
        }
        await db.delete('MEDIA', where: 'PATH = ?', whereArgs: [item.path]);
        yield i;
      }
    } catch (error, stack) {
      print('$error\n$stack');
      yield* _yieldError(error);
    }
  }

  Stream<DbRow> _exportToFolderWorker(_ExportToFolderMessage message) async* {
    try {
      const FileSystem fs = LocalFileSystem();
      final Directory parent = fs.directory(message.folder);
      for (MediaItem item in message.items) {
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
      }
    } catch (error, stack) {
      print('$error\n$stack');
      yield* _yieldError(error);
    }
  }

  Stream<T> _yieldError<T>(dynamic error) async* {
    throw error;
  }
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

  _MediaNotifier? _collectionNotifier;
  final Map<String, _MediaNotifier> _itemNotifiers = <String, _MediaNotifier>{};

  late MediaItems _items;
  MediaItems get items => _items;

  void addCollectionListener(VoidCallback listener) {
    _collectionNotifier ??= _MediaNotifier();
    _collectionNotifier!.addListener(listener);
  }

  void removeCollectionListener(VoidCallback listener) {
    assert(_collectionNotifier != null);
    _collectionNotifier!.removeListener(listener);
    if (!_collectionNotifier!.hasListeners) {
      _collectionNotifier!.dispose();
      _collectionNotifier = null;
    }
  }

  void _notifyCollectionChanged() {
    _collectionNotifier?.notifyListeners();
  }

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
    _items = MediaItems.fromDbResults(results);
    _instance = this;
  }
}

class _MediaNotifier extends Object with ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();

  @override
  bool get hasListeners => super.hasListeners;
}
