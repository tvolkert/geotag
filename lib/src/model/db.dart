import 'dart:async';

import 'package:collection/collection.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'gps.dart';
import 'image.dart';
import 'isolates.dart';
import 'metadata.dart';
import 'video.dart';

typedef DbRow = Map<String, Object?>;
typedef DbResults = List<DbRow>;

typedef FileModifiedHandler = void Function(DbRow row);

enum MediaType {
  photo,
  video,
}

extension DbRowExtensions on DbRow {
  MediaType get type => MediaType.values[this['TYPE'] as int];
  set type(MediaType value) => this['TYPE'] = value.index;

  String get path => this['PATH'] as String;
  set path(String value) => this['PATH'] = value;

  String get photoPath => this['PHOTO_PATH'] as String;
  set photoPath(String value) => this['PHOTO_PATH'] = value;

  Uint8List get thumbnail => this['THUMBNAIL'] as Uint8List;
  set thumbnail(Uint8List value) => this['THUMBNAIL'] = value;

  bool get hasLatlng => this['LATLNG'] != null;
  String? get latlng => this['LATLNG'] as String?;
  set latlng(String? value) => this['LATLNG'] = value;

  bool get hasDateTimeOriginal => this['DATETIME_ORIGINAL'] != null;

  DateTime? get dateTimeOriginal {
    return hasDateTimeOriginal
        ? DateTime.fromMillisecondsSinceEpoch(this['DATETIME_ORIGINAL'] as int)
        : null;
  }

  set dateTimeOriginal(DateTime? value) {
    this['DATETIME_ORIGINAL'] = value?.millisecondsSinceEpoch;
  }

  bool get hasDateTimeDigitized => this['DATETIME_DIGITIZED'] != null;

  DateTime? get dateTimeDigitized {
    return hasDateTimeDigitized
        ? DateTime.fromMillisecondsSinceEpoch(this['DATETIME_DIGITIZED'] as int)
        : null;
  }

  set dateTimeDigitized(DateTime? value) {
    this['DATETIME_DIGITIZED'] = value?.millisecondsSinceEpoch;
  }

  bool get hasDateTime => hasDateTimeOriginal || hasDateTimeDigitized;

  DateTime? get dateTime => dateTimeOriginal ?? dateTimeDigitized;

  GpsCoordinates? get coords => hasLatlng ? GpsCoordinates.fromString(latlng!) : null;

  bool get isModified => this['MODIFIED'] == 1;
  set isModified(bool value) => this['MODIFIED'] = value ? 1 : 0;

  DateTime get lastModified {
    return DateTime.fromMillisecondsSinceEpoch(this['DATETIME_LAST_MODIFIED'] as int);
  }

  set lastModified(DateTime value) {
    this['DATETIME_LAST_MODIFIED'] = value.millisecondsSinceEpoch;
  }

  Future<void> commit() async {
    await _writeToDb(DatabaseBinding.instance.db);
    _notify();
  }

  Future<void> _writeToDb(Database db) {
    return db.update(
      'MEDIA',
      <String, Object?>{
        'LATLNG': this['LATLNG'],
        'DATETIME_ORIGINAL': this['DATETIME_ORIGINAL'],
        'DATETIME_DIGITIZED': this['DATETIME_DIGITIZED'],
        'MODIFIED': this['MODIFIED'],
        'DATETIME_LAST_MODIFIED': this['DATETIME_LAST_MODIFIED'],
      },
      where: 'PATH = ?',
      whereArgs: <String>[path],
    );
  }

  void _notify() {
    DatabaseBinding.instance._notify(this);
  }
}

extension DbResultsExtensions on DbResults {
  Stream<DbRow> addFiles(Iterable<String> paths) async* {
    const FileSystem fs = LocalFileSystem();
    final Directory appSupportDir = fs.directory(await getApplicationSupportDirectory());
    final _AddFilesMessage message = _AddFilesMessage._(DatabaseBinding.instance.dbFile.absolute.path, appSupportDir.absolute.path, paths);
    final Stream<DbRow> rows = Isolates.stream<_AddFilesMessage, DbRow>(_addFilesWorker, message);
    await for (final DbRow row in rows) {
      add(row);
      yield row;
    }
  }

  Stream<DbRow> writeFilesToDisk() async* {
    // TODO: provide hook whereby caller can cancel operation.
    final _WriteToDiskMessage message = _WriteToDiskMessage._(DatabaseBinding.instance.dbFile.absolute.path, DbResults.from(this));
    final Stream<int> iter = Isolates.stream<_WriteToDiskMessage, int>(_writeToDiskWorker, message);
    await for (final int i in iter) {
      // The changes have already been written to disk, but the changes were
      // done in a separate isolate, so the local row object in this isolate
      // needs to be updated to match.
      this[i]
          ..isModified = false
          .._notify()
          ;
      yield this[i];
    }
  }

  Stream<DbRow> deleteFiles(Iterable<int> indexes) async* {
    // TODO: provide hook whereby caller can cancel operation.
    assert(indexes.length <= length);
    assert(indexes.every((int index) => index < length));
    DbResults filtered = DbResults.empty(growable: true);
    for (int i in indexes) {
      filtered.add(DbRow.from(this[i])..putIfAbsent('index', () => i));
    }
    final _DeleteFilesMessage message = _DeleteFilesMessage._(DatabaseBinding.instance.dbFile.absolute.path, filtered.reversed.toList());
    final Stream<DbRow> iter = Isolates.stream<_DeleteFilesMessage, DbRow>(_deleteFilesWorker, message);
    await for (final DbRow row in iter) {
      final int index = row['index'] as int;
      final DbRow removed = removeAt(index);
      yield removed;
    }
  }

  Stream<void> exportToFolder(String folder) {
    final _ExportToFolderMessage message = _ExportToFolderMessage._(folder, map<String>((DbRow row) => row.path));
    return Isolates.stream<_ExportToFolderMessage, void>(_exportToFolderWorker, message);
  }

  /// This runs in a separate isolate.
  Stream<DbRow> _addFilesWorker(_AddFilesMessage message) async* {
    const FileSystem fs = LocalFileSystem();
    databaseFactory = databaseFactoryFfi;
    final Database db = await openDatabase(message.dbPath);
    final ChrootFileSystem chrootFs = ChrootFileSystem(fs, fs.path.join(message.appSupportPath, 'media'));
    for (String path in message.paths) {
      final Uint8List bytes = fs.file(path).readAsBytesSync();
      chrootFs.file(path).parent.createSync(recursive: true);
      chrootFs.file(path).writeAsBytesSync(bytes);
      final String chrootPath = '${chrootFs.root}$path';
      assert(fs.file(chrootPath).existsSync());
      assert(const ListEquality<int>().equals(fs.file(path).readAsBytesSync(), chrootFs.file(path).readAsBytesSync()));

      if (path.toLowerCase().endsWith('jpg') || path.toLowerCase().endsWith('.jpeg')) {
        final JpegFile jpeg = JpegFile(path);
        final GpsCoordinates? coords = jpeg.getGpsCoordinates();
        final DateTime? dateTimeOriginal = jpeg.getDateTimeOriginal();
        final DateTime? dateTimeDigitized = jpeg.getDateTimeDigitized();
        DbRow row = DbRow()
          ..type = MediaType.photo
          ..path = chrootPath
          ..photoPath = chrootPath
          ..thumbnail = jpeg.bytes
          ..latlng = coords?.latlng
          ..dateTimeOriginal = dateTimeOriginal
          ..dateTimeDigitized = dateTimeDigitized
          ..lastModified = DateTime.now()
          ..isModified = false
          ;
        await db.insert('MEDIA', row);
        yield row;
      } else if (path.toLowerCase().endsWith('.mp4')) {
        final Mp4 mp4 = Mp4(path);
        final Metadata metadata = mp4.extractMetadata();
        final String extractedFramePath = '$path.jpg';
        mp4.extractFrame(chrootFs, extractedFramePath);
        DbRow row = DbRow()
          ..type = MediaType.video
          ..path = chrootPath
          ..photoPath = '${chrootFs.root}$extractedFramePath'
          ..thumbnail = metadata.thumbnail
          ..latlng = metadata.coordinates?.latlng
          ..dateTimeOriginal = metadata.dateTime
          ..dateTimeDigitized = metadata.dateTime
          ..lastModified = DateTime.now()
          ..isModified = false
          ;
        await db.insert('MEDIA', row);
        yield row;
      }
    }
  }

  Stream<int> _writeToDiskWorker(_WriteToDiskMessage message) async* {
    databaseFactory = databaseFactoryFfi;
    final Database db = await openDatabase(message.dbPath);
    for (int i = 0; i < message.rows.length; i++) {
      final DbRow row = message.rows[i];
      switch (row.type) {
        case MediaType.photo:
          final JpegFile jpeg = JpegFile(row.path);
          bool needsWrite = false;
          if (row.hasDateTimeOriginal) {
            needsWrite = true;
            jpeg.setDateTimeOriginal(row.dateTimeOriginal!);
          }
          if (row.hasDateTimeDigitized) {
            needsWrite = true;
            jpeg.setDateTimeDigitized(row.dateTimeDigitized!);
          }
          if (row.hasLatlng) {
            needsWrite = true;
            jpeg.setGpsCoordinates(GpsCoordinates.fromString(row.latlng!));
          }
          if (needsWrite) {
            jpeg.write();
          }
        case MediaType.video:
          final Mp4 mp4 = Mp4(row.path);
          await mp4.writeMetadata(dateTime: row.dateTime, coordinates: row.coords);
      }
      row.isModified = false;
      await row._writeToDb(db);
      yield i;
    }
  }

  Stream<DbRow> _deleteFilesWorker(_DeleteFilesMessage message) async* {
    databaseFactory = databaseFactoryFfi;
    final Database db = await openDatabase(message.dbPath);
    const FileSystem fs = LocalFileSystem();
    for (int i = 0; i < message.rows.length; i++) {
      final DbRow row = message.rows[i];
      fs.file(row.path).deleteSync();
      if (row.path != row.photoPath) {
        fs.file(row.photoPath).deleteSync();
      }
      await db.delete('MEDIA', where: 'PATH = ?', whereArgs: [row.path]);
      yield row;
    }
  }

  Stream<void> _exportToFolderWorker(_ExportToFolderMessage message) async* {
    const FileSystem fs = LocalFileSystem();
    final Directory parent = fs.directory(message.folder);
    for (String path in message.paths) {
      final String basename = fs.file(path).basename;
      File target = parent.childFile(basename);
      for (int i = 1; target.existsSync(); i++) {
        // Resolve collision
        target = parent.childFile('$basename ($i)');
      }
      fs.file(path).copySync(target.path);
      yield null;
    }
  }
}

class _AddFilesMessage {
  const _AddFilesMessage._(this.dbPath, this.appSupportPath, this.paths);

  final String dbPath;
  final String appSupportPath;
  final Iterable<String> paths;
}

class _WriteToDiskMessage {
  const _WriteToDiskMessage._(this.dbPath, this.rows);

  final String dbPath;
  final DbResults rows;
}

class _DeleteFilesMessage {
  const _DeleteFilesMessage._(this.dbPath, this.rows);

  final String dbPath;
  final DbResults rows;
}

class _ExportToFolderMessage {
  const _ExportToFolderMessage._(this.folder, this.paths);

  final String folder;
  final Iterable<String> paths;
}

mixin DatabaseBinding on AppBindingBase {
  /// The singleton instance of this object.
  static late DatabaseBinding _instance;
  static DatabaseBinding get instance => _instance;

  late File _dbFile;
  File get dbFile => _dbFile;

  late Database _db;
  Database get db => _db;

  final Map<String, FileModifiedHandler> _fileListeners = <String, FileModifiedHandler>{};

  Future<DbResults> getAllPhotos({bool modifiable = true}) async {
    DbResults results = await db.query('MEDIA', orderBy: 'ITEM_ID');
    if (modifiable) {
      results = DbResults.generate(results.length, (int index) {
        return DbRow.from(results[index]);
      });
    }
    return results;
  }

  Future<DbRow?> getPhoto(String path) async {
    DbResults results = await db.query('MEDIA', where: 'PATH = ?', whereArgs: [path]);
    return results.isEmpty ? null : DbRow.from(results.first);
  }

  void setFileListener(String path, FileModifiedHandler? listener) {
    if (listener == null) {
      _fileListeners.remove(path);
    } else {
      _fileListeners[path] = listener;
    }
  }

  void _notify(DbRow row) {
    final FileModifiedHandler? listener = _fileListeners[row.path];
    if (listener != null) {
      listener(row);
    }
  }

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _instance = this;

    const FileSystem fs = LocalFileSystem();
    final Directory appSupportDir = fs.directory(await getApplicationSupportDirectory());
    final ByteData photosDb = await rootBundle.load('assets/photos.db');
    final File dbFile = _dbFile = appSupportDir.childFile('photos.db');
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }
    if (!dbFile.existsSync()) {
      await dbFile.writeAsBytes(photosDb.buffer.asUint8List());
    }
    _db = await openDatabase(dbFile.absolute.path);
  }
}
