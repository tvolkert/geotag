import 'dart:async';
import 'dart:isolate';

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

typedef DbRow = Map<String, Object?>;
typedef DbResults = List<DbRow>;

extension DbRowExtensions on DbRow {
  String get path => this['PATH'] as String;
  set path(String value) => this['PATH'] = value;

  String? get lanlng => this['LATLNG'] as String?;
  set latlng(String? value) => this['LATLNG'] = value;

  bool get isModified => this['MODIFIED'] == 1;
  set isModified(bool value) => this['MODIFIED'] = value ? 1 : 0;

  Object get lastModified => this['LAST_MODIFIED']!;
  set lastModified(Object value) => this['LAST_MODIFIED'] = value;
}

extension DbResultsExtensions on DbResults {
  Stream<DbRow> addFiles(Iterable<String> paths) async* {
    final _AddFilesMessage message = _AddFilesMessage._(DatabaseBinding.instance.dbFile.absolute.path, paths);
    final Stream<DbRow> rows = Isolates.stream<_AddFilesMessage, DbRow>(_addFilesWorker, message);
    await for (final DbRow row in rows) {
      add(row);
      yield row;
    }
  }

  /// This runs in a separate isolate.
  Stream<DbRow> _addFilesWorker(_AddFilesMessage message) async* {
    databaseFactory = databaseFactoryFfi;
    final Database db = await openDatabase(message.dbPath);
    for (final String path in message.paths) {
      final JpegFile jpeg = JpegFile(path);
      final GpsCoordinates? coords = jpeg.getGpsCoordinates();
      DbRow row = DbRow()
        ..path = path
        ..latlng = coords?.latlng
        ..isModified = false
        ..lastModified = DateTime.now().millisecondsSinceEpoch;
      await db.insert('PHOTO', row);
      yield row;
    }
  }
}

class _AddFilesMessage {
  const _AddFilesMessage._(this.dbPath, this.paths);

  final String dbPath;
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

  Future<DbResults> getAllPhotos({bool modifiable = true}) async {
    DbResults results = await db.query('PHOTO', orderBy: 'LAST_MODIFIED');
    if (modifiable) {
      results = DbResults.from(results);
    }
    return results;
  }

  Future<DbRow?> getPhoto(String path) async {
    DbResults results = await db.query('PHOTO', where: 'PATH = ?', whereArgs: [path]);
    return results.isEmpty ? null : results.first;
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
