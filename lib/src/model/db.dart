import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';

typedef DbRow = Map<String, Object?>;
typedef DbResults = List<DbRow>;

extension DbRowExtensions on DbRow {
  String get path => this['PATH'] as String;
  set path(String value) => this['PATH'] = value;

  bool get isTagged => this['TAGGED'] == 1;
  set isTagged(bool value) => this['TAGGED'] = value ? 1 : 0;

  bool get isModified => this['MODIFIED'] == 1;
  set isModified(bool value) => this['MODIFIED'] = value ? 1 : 0;

  Object get lastModified => this['LAST_MODIFIED']!;
  set lastModified(Object value) => this['LAST_MODIFIED'] = value;
}

extension DbResultsExtensions on DbResults {
  Future<void> addFiles(Iterable<String> paths) async {
    final Database db = DatabaseBinding.instance.db;
    for (final String path in paths) {
      DbRow row = DbRow()
        ..path = path
        ..isTagged = false
        ..isModified = false
        ..lastModified = DateTime.now().millisecondsSinceEpoch;
      await db.insert('PHOTO', row);
      add(row);
    }
  }
}

mixin DatabaseBinding on AppBindingBase {
  /// The singleton instance of this object.
  static late DatabaseBinding _instance;
  static DatabaseBinding get instance => _instance;

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
    final File dbFile = appSupportDir.childFile('photos.db');
    if (!appSupportDir.existsSync()) {
      appSupportDir.createSync(recursive: true);
    }
    if (!dbFile.existsSync()) {
      await dbFile.writeAsBytes(photosDb.buffer.asUint8List());
    }
    _db = await openDatabase(dbFile.absolute.path);
  }
}
