// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:collection';

import 'package:chicago/chicago.dart' as chicago show binarySearch;
import 'package:collection/collection.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geotag/src/extensions/iterable.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

import '../foundation/base.dart';
import '../foundation/isolates.dart';
import '../bindings/clock.dart';
import '../bindings/db.dart';
import '../bindings/files.dart';
import 'gps.dart';
import 'image.dart';
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
///
/// Since media items maintain references to their owner [MediaItems], which
/// in turn maintain references to event listeners, media items should not be
/// sent through an isolate's send port.
//@vmIsolateUnsendable TODO: expose this annotation? It's used in Completer.
class MediaItem {
  /// Creates a new [MediaItem] with no metadata.
  MediaItem._empty()
      : _row = DbRow(),
        _unsavedRow = DbRow();

  /// Creates a new [MediaItem] from the specified database row.
  ///
  /// The [row] will be used directly as the backing data structure for this
  /// newly created item, so changes to the row will be reflected in this
  /// item.
  MediaItem.fromDbRow(DbRow row)
      : _row = row,
        _unsavedRow = DbRow.from(row);

  final DbRow _row;
  final DbRow _unsavedRow;
  RootMediaItems? _owner;

  bool get _isAttached => _owner != null;

  void _attach(RootMediaItems items) {
    assert(!_isAttached);
    _owner = items;
  }

  void _detach() {
    assert(_isAttached);
    _owner = null;
  }

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

  /// Whether this media item has an event attached to it.
  bool get hasEvent => _row['EVENT'] != null;

  /// The event associated with this media item, if any.
  ///
  /// Changes to this value will not be visible (and listeners will not be
  /// notified) until [commit] is called.
  String? get event => _row['EVENT'] as String?;
  set event(String? value) {
    _unsavedRow['EVENT'] = value;
  }

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

  /// Returns a new media item that contains a copy of this item's metadata but
  /// none of this item's unsaved edits.
  ///
  /// The cloned media item will be unattached to any list.
  MediaItem clone() => MediaItem.fromDbRow(DbRow.from(_row));

  /// Writes this media item's metadata fields to the database and notifies
  /// listeners that the metadata has changed.
  Future<void> commit() async {
    assert(_isAttached);
    await _writePendingEditsToDb(DatabaseBinding.instance.db);
    _persistPendingEdits();
  }

  Future<void> _writePendingEditsToDb(sqflite.Database db) {
    return db.update(
      'MEDIA',
      <String, Object?>{
        'LATLNG': _unsavedRow['LATLNG'],
        'DATETIME_ORIGINAL': _unsavedRow['DATETIME_ORIGINAL'],
        'DATETIME_DIGITIZED': _unsavedRow['DATETIME_DIGITIZED'],
        'EVENT': _unsavedRow['EVENT'],
        'MODIFIED': _unsavedRow['MODIFIED'],
        'DATETIME_LAST_MODIFIED': _unsavedRow['DATETIME_LAST_MODIFIED'],
      },
      where: 'ITEM_ID = ?',
      whereArgs: <int>[id],
    );
  }

  void _persistPendingEdits() {
    assert(_isAttached);
    _owner!._updateItem(this);
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
  /// Subclasses are both (a) required, and (b) only ever allowed to return 0
  /// when [a] and [b] are logically equal (operator `==` returns true).
  /// Otherwise, comparators must find a way to break the equality.
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

final class ByFilename extends MediaItemComparator {
  const ByFilename(super.direction);

  static const ById _byId = ById(Ascending());

  @override
  @protected
  int doCompare(MediaItem a, MediaItem b) {
    if (a == b) {
      return 0;
    }
    final int result = a.path.compareTo(b.path);
    return result != 0 ? result : _byId.compare(a, b);
  }
}

final class ByDate extends MediaItemComparator {
  const ByDate(super.direction);

  static const ById _byId = ById(Ascending());

  @override
  @protected
  int doCompare(MediaItem a, MediaItem b) {
    if (a == b) {
      return 0;
    } else if (a.dateTime == null && b.dateTime == null) {
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

  final List<MediaItem> _items;

  /// A newly created copy of the list of [DbRow] objects that backs this
  /// object's items.
  DbResults get _rows => DbResults.from(_items.map<DbRow>((MediaItem item) => item._row));

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  MediaItem get first => _items.first;

  MediaItem get last => _items.last;

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

  final LinkedList<_FilteredItemsWeakRef> _children = LinkedList<_FilteredItemsWeakRef>();
  MediaNotifier? _structureNotifier;

  /// The media items list whence this list was created.
  ///
  /// If the parent list is non-null, then it will be a superset of this list.
  ///
  /// This will be non-null for all lists except the [root] list.
  MediaItems? get parent;

  /// The media items list that exists at the root of the [parent] hierarchy.
  RootMediaItems get root;

  /// Adds a listener to be notified when the structure of this list changes.
  ///
  /// A [MediaItems] list is said to have changed structure when either its
  /// order or its [length] has changed. Its order can change either by virtue of
  /// its [comparator] being modified or by virtue of one of its items changing
  /// its metadata such that it now exists in a different place in the list (as
  /// determined by the [comparator]).
  void addStructureListener(VoidCallback listener) {
    _structureNotifier ??= MediaNotifier();
    _structureNotifier!.addListener(listener);
  }

  /// Removes a listener that was added with [addStructureListener].
  void removeStructureListener(VoidCallback listener) {
    assert(_structureNotifier != null);
    _structureNotifier!.removeListener(listener);
    if (!_structureNotifier!.hasListeners) {
      _structureNotifier!.dispose();
      _structureNotifier = null;
    }
  }

  void _notifyStructureListeners() {
    _structureNotifier?.notifyListeners();
  }

  /// The comparator that determines the sort order of this list.
  ///
  /// New items that are added to the list (via [RootMediaItems.addFiles]) will
  /// automatically be added in order, and updates to [MediaItem] metadata for
  /// items in the list will cause those items to automatically be moved to the
  /// appropriate new location in the list as to maintain the sort order.
  ///
  /// Updating the comparator will cause the sort order to correspondingly be
  /// updated, thus notifying listeners that were added via
  /// [addStructureListener].
  MediaItemComparator get comparator;
  set comparator(MediaItemComparator value);

  /// Whether this list contains any items with their [MediaItem.isModified]
  /// bit set.
  bool get containsModified => _items.where((MediaItem item) => item.isModified).isNotEmpty;

  static bool _isModified(MediaItem item) => item.isModified;

  /// Returns a child media items list containing only those items in this list
  /// that have their [MediaItem.isModified] bit set.
  ///
  /// The returned list will have its [parent] list set to this list.
  MediaItems get whereModified => where(const PredicateMediaItemFilter(_isModified));

  /// Returns a child media items list containing only those items in this list
  /// that pass the specified [filter].
  MediaItems where(MediaItemFilter filter) {
    final FilteredMediaItems result = FilteredMediaItems._(filter, this);
    _children.add(_FilteredItemsWeakRef(result));
    return result;
  }

  /// Visits each child media items list that has been created and not yet
  /// garbage collected.
  void _forEachChild(void Function(FilteredMediaItems items) visitor) {
    List<_FilteredItemsWeakRef>? cleared;
    for (_FilteredItemsWeakRef reference in List<_FilteredItemsWeakRef>.from(_children)) {
      if (reference.isCleared) {
        cleared ??= <_FilteredItemsWeakRef>[];
        cleared.add(reference);
      } else {
        visitor(reference.target);
      }
    }
    if (cleared != null) {
      for (_FilteredItemsWeakRef reference in cleared) {
        reference.unlink();
      }
    }
  }

  /// Returns the index of the specified [item] in this list, or -1 if the item
  /// does not appear in this list.
  ///
  /// This uses the [comparator] to perform a binary search, so this method runs
  /// in O(log n) time.
  int indexOf(MediaItem item) {
    final int index = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
    return index < 0 ? -1 : index;
  }

  /// Writes these media items to disk, encoding their metadata in their files.
  ///
  /// Returns a stream that will yield an event for every item in this list as
  /// each item is written to disk.
  Stream<void> writeFilesToDisk() {
    // TODO: provide hook whereby caller can cancel operation.
    final List<MediaItem> localItems = List<MediaItem>.from(_items);
    final _WriteToDiskMessage message = _WriteToDiskMessage._(
      DatabaseBinding.instance.databaseFactory,
      FilesBinding.instance.fs,
      _rows,
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
        .._persistPendingEdits();
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  /// Deletes the items in this list.
  ///
  /// Returns a stream that will yield an event for every item that was deleted.
  /// When this stream is done, will not contain any items ([isEmpty] will
  /// return true).
  Stream<void> deleteFiles() {
    // TODO: provide hook whereby caller can cancel operation.
    final List<MediaItem> localItems = List<MediaItem>.from(_items);
    final _DeleteFilesMessage message = _DeleteFilesMessage._(
      DatabaseBinding.instance.databaseFactory,
      FilesBinding.instance.fs,
      _rows,
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
      root._removeItemAt(root.indexOf(removed));
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  /// Exports the items in this list to the specified folder.
  ///
  /// The folder will be resolved using [FilesBinding.fs].
  ///
  /// The contents of this list will not be modified by this operation.
  ///
  /// Returns a stream that will yield an event for every item in this list as
  /// each item is exported to the folder.
  Stream<void> exportToFolder(String folder) {
    final _ExportToFolderMessage message = _ExportToFolderMessage._(
      FilesBinding.instance.fs,
      folder,
      _rows,
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

  /// This runs in a separate isolate.
  static Stream<int> _writeToDiskWorker(_WriteToDiskMessage message) async* {
    final sqflite.Database db = await message.dbFactory();
    for (int i = 0; i < message.rows.length; i++) {
      final MediaItem item = MediaItem.fromDbRow(message.rows[i]);
      try {
        switch (item.type) {
          case MediaType.photo:
            final JpegFile jpeg = JpegFile(item.path, message.fs);
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
            final Mp4 mp4 = Mp4(item.path, message.fs);
            await mp4.writeMetadata(dateTime: item.dateTime, coordinates: item.coords);
        }
        item.isModified = false;
        await item._writePendingEditsToDb(db);
        yield i;
      } catch (error, stack) {
        yield* Stream<int>.error(WrappedError(error, 'While processing ${item.path}}'), stack);
      }
    }
  }

  /// This runs in a separate isolate.
  static Stream<int> _deleteFilesWorker(_DeleteFilesMessage message) async* {
    final sqflite.Database db = await message.dbFactory();
    // Traverse the list backwards so that our stream of indexes will be valid
    // even as we remove items from the list.
    for (int i = message.rows.length - 1; i >= 0; i--) {
      final MediaItem item = MediaItem.fromDbRow(message.rows[i]);
      try {
        message.fs.file(item.path).deleteSync();
        if (item.path != item.photoPath) {
          message.fs.file(item.photoPath).deleteSync();
        }
        await db.delete('MEDIA', where: 'PATH = ?', whereArgs: [item.path]);
        yield i;
      } catch (error, stack) {
        yield* Stream<int>.error(WrappedError(error, 'While processing ${item.path}}'), stack);
      }
    }
  }

  /// This runs in a separate isolate.
  static Stream<DbRow> _exportToFolderWorker(_ExportToFolderMessage message) async* {
    final Directory root = message.fs.directory(message.folder);
    assert(root.existsSync());
    for (final DbRow row in message.rows) {
      final MediaItem item = MediaItem.fromDbRow(row);
      try {
        final int year = item.hasDateTime ? item.dateTime!.year : 0;
        final Directory parent = root
            .childDirectory(year.toString().padLeft(4, '0'))
            .childDirectory(item.event ?? 'No Event');
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }
        final String path = item.path;
        final String basename = message.fs.file(path).basename;
        File target = parent.childFile(basename);
        for (int i = 1; target.existsSync(); i++) {
          // Resolve collision
          // TODO: put the parents before the file extension
          target = parent.childFile('$basename ($i)');
        }
        // https://github.com/flutter/flutter/issues/140763
        await message.fs.file(path).copy(target.path);
        yield row;
      } catch (error, stack) {
        yield* Stream<DbRow>.error(WrappedError(error, 'While processing ${item.path}}'), stack);
      }
    }
  }
}

/// A synthetic media items list that is always empty.
///
/// Mutator methods on this type of media items list are all unsupported and
/// will throw an error if they are invoked.
final class EmptyMediaItems extends MediaItems {
  EmptyMediaItems() : super._(List<MediaItem>.empty());

  @override
  MediaItems? get parent => null;

  @override
  RootMediaItems get root => throw UnsupportedError('root');

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

/// An unfiltered media items list with no parent.
final class RootMediaItems extends MediaItems {
  RootMediaItems.fromDbResults(DbResults results)
      : _comparator = const ById(Ascending()),
        super._(results.map<MediaItem>(MediaItem.fromDbRow).toList()) {
    for (MediaItem item in _items) {
      item._attach(this);
    }
  }

  MediaItemComparator _comparator;
  final Map<int?, MediaNotifier> _metadataNotifiers = <int?, MediaNotifier>{};

  @override
  MediaItems? get parent => null;

  @override
  RootMediaItems get root => this;

  @override
  MediaItemComparator get comparator => _comparator;

  @override
  set comparator(MediaItemComparator value) {
    if (value != _comparator) {
      final MediaItemComparator oldComparator = _comparator;
      _comparator = value;
      final List<MediaItem> oldItems = List<MediaItem>.from(_items);
      _items.sort(value.compare);
      _forEachChild((FilteredMediaItems items) {
        items._handleParentSorted(oldItems, oldComparator);
      });
      _notifyStructureListeners();
    }
  }

  void addMetadataListener(VoidCallback listener, {int? id}) {
    final MediaNotifier notifier = _metadataNotifiers.putIfAbsent(id, () => MediaNotifier());
    notifier.addListener(listener);
  }

  void removeMetadataListener(VoidCallback listener, {int? id}) {
    final MediaNotifier? notifier = _metadataNotifiers[id];
    assert(notifier != null);
    notifier!.removeListener(listener);
    if (!notifier.hasListeners) {
      notifier.dispose();
      _metadataNotifiers.remove(id);
    }
  }

  void _insertItem(MediaItem item) {
    assert(!item._isAttached);
    int index = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
    assert(index < 0);
    index = -index - 1;
    _items.insert(index, item);
    item._attach(this);
    assert(() {
      final List<MediaItem> copy = List<MediaItem>.from(_items)..sort(_comparator.compare);
      return const ListEquality<MediaItem>().equals(_items, copy);
    }());
    _forEachChild((FilteredMediaItems items) {
      items._handleParentItemInsertedAt(index);
    });
    _notifyStructureListeners();
  }

  void _updateItem(MediaItem item) {
    assert(item._owner == this);
    final int oldIndex = indexOf(item);
    assert(oldIndex >= 0);
    // Remove and re-insert to make sure it's sorted correctly.
    MediaItem removed = _items.removeAt(oldIndex);
    assert(removed == item);
    removed = item.clone();
    item._row.addAll(item._unsavedRow);
    int newIndex = chicago.binarySearch<MediaItem>(_items, item, compare: comparator.compare);
    assert(newIndex < 0);
    newIndex = -newIndex - 1;
    _items.insert(newIndex, item);
    _metadataNotifiers[item.id]?.notifyListeners();
    _metadataNotifiers[null]?.notifyListeners();
    _forEachChild((FilteredMediaItems items) {
      items._handleParentItemUpdated(oldIndex, newIndex, removed);
    });
    if (oldIndex != newIndex) {
      _notifyStructureListeners();
    }
  }

  MediaItem _removeItemAt(int index) {
    assert(index >= 0);
    final MediaItem removed = _items.removeAt(index);
    assert(removed._owner == this);
    removed._detach();
    _forEachChild((FilteredMediaItems items) {
      items._handleParentItemRemovedAt(index, removed);
    });
    _notifyStructureListeners();
    return removed;
  }

  /// Adds the files specified by [paths] to this media item list.
  ///
  /// Returns a stream that will yield an event for every item that was added as
  /// they are added. If an item fails to add for any reason, the stream will
  /// yield an error event, such that the total number of stream events is
  /// guaranteed to match the length of the [paths] input.
  ///
  /// The files will be resolved using [FilesBinding.fs].
  ///
  /// This will notify structure listeners (see [addStructureListener]) once
  /// for each item that is added.
  Stream<void> addFiles(Iterable<String> paths) {
    final Directory appSupportDir = FilesBinding.instance.applicationSupportDirectory;
    final _AddFilesMessage message = _AddFilesMessage._(
      DatabaseBinding.instance.databaseFactory,
      FilesBinding.instance.fs,
      ClockBinding.instance.now,
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
      _insertItem(item);
      controller.add(null);
    }, onError: controller.addError, onDone: controller.close);
    return controller.stream;
  }

  /// This runs in a separate isolate.
  static Stream<DbRow> _addFilesWorker(_AddFilesMessage message) async* {
    final sqflite.Database db = await message.dbFactory();
    final ChrootFileSystem chrootFs = ChrootFileSystem(
      message.fs,
      message.fs.path.join(message.appSupportPath, 'media'),
    );
    for (String path in message.paths) {
      try {
        final String extension = path.split('.').last.toLowerCase();
        final Uint8List bytes = message.fs.file(path).readAsBytesSync();
        chrootFs.file(path).parent.createSync(recursive: true);
        chrootFs.file(path).writeAsBytesSync(bytes);
        final String chrootPath = '${chrootFs.root}$path';
        assert(message.fs.file(chrootPath).existsSync());
        assert(const ListEquality<int>().equals(
          message.fs.file(path).readAsBytesSync(),
          chrootFs.file(path).readAsBytesSync(),
        ));

        Future<DbRow> insertRow(Metadata metadata, MediaType type) async {
          MediaItem item = MediaItem._empty()
            ..type = type
            ..path = chrootPath
            ..photoPath = metadata.photoPath
            ..thumbnail = metadata.thumbnail
            ..latlng = metadata.coordinates?.latlng
            ..dateTimeOriginal = metadata.dateTimeOriginal
            ..dateTimeDigitized = metadata.dateTimeDigitized
            ..lastModified = message.now()
            ..isModified = false;
          item.id = await db.insert('MEDIA', item._unsavedRow);
          return item._unsavedRow;
        }

        if (JpegFile.allowedExtensions.contains(extension)) {
          final JpegFile jpeg = JpegFile(chrootPath, message.fs);
          final Metadata metadata = jpeg.extractMetadata();
          yield await insertRow(metadata, MediaType.photo);
        } else if (Mp4.allowedExtensions.contains(extension)) {
          final Mp4 mp4 = Mp4(chrootPath, message.fs);
          final Metadata metadata = mp4.extractMetadata();
          yield await insertRow(metadata, MediaType.video);
        } else {
          yield* Stream<DbRow>.error(UnsupportedError('Unsupported file: $path'));
        }
      } catch (error, stack) {
        if (chrootFs.file(path).existsSync()) {
          chrootFs.file(path).deleteSync();
        }
        yield* Stream<DbRow>.error(AddFileError(error, 'While processing $path', path), stack);
      }
    }
  }
}

abstract base class MediaItemFilter {
  const MediaItemFilter();

  Iterable<MediaItem> apply(List<MediaItem> source);

  @mustCallSuper
  void dispose() {}

  @protected
  @mustCallSuper
  void handleParentItemInsertedAt(int index) {}

  @protected
  @mustCallSuper
  void handleParentItemUpdated(int oldIndex, int newIndex, MediaItem beforeUpdate) {}

  @protected
  @mustCallSuper
  void handleParentItemRemovedAt(int index, MediaItem removed) {}

  @protected
  @mustCallSuper
  void handleParentSorted(List<MediaItem> oldItems, MediaItemComparator oldComparator,
      List<MediaItem> items, MediaItemComparator comparator) {}
}

final class PredicateMediaItemFilter extends MediaItemFilter {
  const PredicateMediaItemFilter(this.condition);

  final Predicate<MediaItem> condition;

  @override
  Iterable<MediaItem> apply(List<MediaItem> source) => source.where(condition);
}

final class IndexedMediaItemFilter extends MediaItemFilter {
  IndexedMediaItemFilter(Iterable<int> indexes) : _indexes = indexes.toList();

  final List<int> _indexes;
  MediaNotifier? _notifier;

  Iterable<int> get indexes => _indexes;

  /// Adds a listener to be notified when the value of [indexes] changes.
  void addListener(VoidCallback listener) {
    _notifier ??= MediaNotifier();
    _notifier!.addListener(listener);
  }

  /// Adds a listener that was added in [addListener].
  void removeListener(VoidCallback listener) {
    if (_notifier != null) {
      _notifier!.removeListener(listener);
      if (!_notifier!.hasListeners) {
        _notifier!.dispose();
        _notifier = null;
      }
    }
  }

  @override
  Iterable<MediaItem> apply(List<MediaItem> source) {
    final List<MediaItem> result = <MediaItem>[];
    for (int index in _indexes) {
      result.add(source[index]);
    }
    return result;
  }

  @override
  void handleParentItemInsertedAt(int index) {
    super.handleParentItemInsertedAt(index);
    bool indexesChanged = false;
    for (int i = 0; i < _indexes.length; i++) {
      final int localIndex = _indexes[i];
      if (localIndex >= index) {
        _indexes[i] = localIndex + 1;
        indexesChanged = true;
      }
    }
    if (indexesChanged) {
      _notifier?.notifyListeners();
    }
  }

  @override
  void handleParentItemUpdated(int oldIndex, int newIndex, MediaItem beforeUpdate) {
    super.handleParentItemUpdated(oldIndex, newIndex, beforeUpdate);
    bool indexesChanged = false;
    for (int i = 0; i < _indexes.length; i++) {
      final int localIndex = _indexes[i];
      if (localIndex == oldIndex) {
        _indexes[i] = newIndex;
        indexesChanged = true;
      } else if (localIndex > oldIndex && localIndex <= newIndex) {
        _indexes[i] = localIndex - 1;
        indexesChanged = true;
      } else if (localIndex < oldIndex && localIndex >= newIndex) {
        _indexes[i] = localIndex + 1;
        indexesChanged = true;
      }
    }
    if (indexesChanged) {
      // Indexes may be out of order now. It's important we keep them sorted to
      // match the sort order dictated by the root comparator.
      _indexes.sort();
      _notifier?.notifyListeners();
    }
  }

  @override
  void handleParentItemRemovedAt(int index, MediaItem removed) {
    super.handleParentItemRemovedAt(index, removed);
    bool indexesChanged = false;
    for (int i = _indexes.length - 1; i >= 0; i--) {
      final int localIndex = _indexes[i];
      if (localIndex == index) {
        _indexes.removeAt(i);
        indexesChanged = true;
      } else if (localIndex > index) {
        _indexes[i] = localIndex - 1;
        indexesChanged = true;
      }
    }
    if (indexesChanged) {
      _notifier?.notifyListeners();
    }
  }

  @override
  void handleParentSorted(List<MediaItem> oldItems, MediaItemComparator oldComparator,
      List<MediaItem> items, MediaItemComparator comparator) {
    super.handleParentSorted(oldItems, oldComparator, items, comparator);
    bool indexesChanged = false;
    for (int i = 0; i < _indexes.length; i++) {
      final int localIndex = _indexes[i];
      final MediaItem item = oldItems[localIndex];
      _indexes[i] = chicago.binarySearch<MediaItem>(items, item, compare: comparator.compare);
      assert(_indexes[i] >= 0);
      if (_indexes[i] != localIndex) {
        indexesChanged = true;
      }
    }
    if (indexesChanged) {
      // Indexes may be out of order now. It's important we keep them sorted to
      // match the sort order dictated by the root comparator.
      _indexes.sort();
      _notifier?.notifyListeners();
    }
  }
}

final class _FilteredItemsWeakRef extends LinkedListEntry<_FilteredItemsWeakRef> {
  _FilteredItemsWeakRef(FilteredMediaItems items)
      : _reference = WeakReference<FilteredMediaItems>(items);

  final WeakReference<FilteredMediaItems> _reference;

  bool get isCleared => _reference.target == null;

  FilteredMediaItems get target => _reference.target!;
}

final class FilteredMediaItems extends MediaItems {
  FilteredMediaItems._(this.filter, this.parent) : super._(<MediaItem>[]) {
    _updateItems();
  }

  final MediaItemFilter filter;

  @override
  final MediaItems parent;

  @override
  RootMediaItems get root {
    MediaItems root = parent;
    while (root is FilteredMediaItems) {
      root = root.parent;
    }
    return root as RootMediaItems;
  }

  void _updateItems() {
    _items
      ..clear()
      ..addAll(filter.apply(parent._items));
  }

  @override
  MediaItemComparator get comparator => parent.comparator;

  @override
  set comparator(MediaItemComparator value) => parent.comparator = value;

  void _handleParentItemInsertedAt(int index) {
    filter.handleParentItemInsertedAt(index);
    _updateItems();
    final int localIndex = indexOf(parent[index]);
    if (localIndex >= 0) {
      _forEachChild((FilteredMediaItems items) {
        items._handleParentItemInsertedAt(localIndex);
      });
      _notifyStructureListeners();
    }
  }

  void _handleParentItemUpdated(int oldIndex, int newIndex, MediaItem beforeUpdate) {
    filter.handleParentItemUpdated(oldIndex, newIndex, beforeUpdate);
    final int localOldIndex = indexOf(beforeUpdate);
    _updateItems();
    final int localNewIndex = indexOf(parent[newIndex]);
    if (localOldIndex == -1 && localNewIndex == -1) {
      // This item isn't in our filter at all; ignore.
      return;
    }
    _forEachChild((FilteredMediaItems items) {
      if (localOldIndex == -1) {
        // Newly matching our filter.
        items._handleParentItemInsertedAt(localNewIndex);
      } else if (localNewIndex == -1) {
        // Newly excluded by our filter.
        items._handleParentItemRemovedAt(localOldIndex, beforeUpdate);
      } else {
        items._handleParentItemUpdated(localOldIndex, localNewIndex, beforeUpdate);
      }
    });
    if (localOldIndex != localNewIndex) {
      _notifyStructureListeners();
    }
  }

  void _handleParentItemRemovedAt(int index, MediaItem removed) {
    filter.handleParentItemRemovedAt(index, removed);
    final int localIndex = indexOf(removed);
    _updateItems();
    assert(indexOf(removed) == -1);
    if (localIndex >= 0) {
      _forEachChild((FilteredMediaItems items) {
        items._handleParentItemRemovedAt(localIndex, removed);
      });
      _notifyStructureListeners();
    }
  }

  void _handleParentSorted(List<MediaItem> oldItems, MediaItemComparator oldComparator) {
    filter.handleParentSorted(oldItems, oldComparator, parent._items, parent.comparator);
    final List<MediaItem> localOldItms = List<MediaItem>.from(_items);
    _updateItems();
    _forEachChild((FilteredMediaItems items) {
      items._handleParentSorted(localOldItms, oldComparator);
    });
    _notifyStructureListeners();
  }
}

class _AddFilesMessage {
  const _AddFilesMessage._(this.dbFactory, this.fs, this.now, this.appSupportPath, this.paths);

  final DatabaseFactory dbFactory;
  final FileSystem fs;
  final TimestampFactory now;
  final String appSupportPath;
  final Iterable<String> paths;
}

class _WriteToDiskMessage {
  const _WriteToDiskMessage._(this.dbFactory, this.fs, this.rows);

  final DatabaseFactory dbFactory;
  final FileSystem fs;
  final DbResults rows;
}

class _DeleteFilesMessage {
  const _DeleteFilesMessage._(this.dbFactory, this.fs, this.rows);

  final DatabaseFactory dbFactory;
  final FileSystem fs;
  final DbResults rows;
}

class _ExportToFolderMessage {
  const _ExportToFolderMessage._(this.fs, this.folder, this.rows);

  final FileSystem fs;
  final String folder;
  final DbResults rows;
}

class MediaNotifier extends Object with ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();

  @override
  bool get hasListeners => super.hasListeners;
}

class AddFileError extends WrappedError {
  AddFileError(super.error, super.message, this.path);

  final String path;
}
