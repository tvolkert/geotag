import 'dart:async';

import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

import 'app.dart';
import 'files.dart';

typedef DbRow = Map<String, Object?>;
typedef DbResults = List<DbRow>;

typedef DatabaseFactory = Future<sqflite.Database> Function();

mixin DatabaseBinding on AppBindingBase, FilesBinding {
  /// The singleton instance of this object.
  static late DatabaseBinding _instance;
  static DatabaseBinding get instance => _instance;

  late File _dbFile;
  File get dbFile => _dbFile;

  late sqflite.Database _db;
  sqflite.Database get db => _db;

  Future<DbResults> getAllMediaItems() async {
    DbResults results = await db.query('MEDIA', orderBy: 'ITEM_ID');
    return DbResults.generate(results.length, (int index) => DbRow.from(results[index]));
  }

  Future<DbRow?> getPhoto(String path) async {
    DbResults results = await db.query('MEDIA', where: 'PATH = ?', whereArgs: [path]);
    return results.isEmpty ? null : DbRow.from(results.first);
  }

  DatabaseFactory get databaseFactory => _createDatabaseFactory(dbFile.absolute.path);

  static DatabaseFactory _createDatabaseFactory(String path) {
    return () {
      sqflite.databaseFactory = sqflite.databaseFactoryFfi;
      return sqflite.openDatabase(path);
    };
  }

  @protected
  Future<sqflite.Database> createDatabase() async {
    return await sqflite.openDatabase(dbFile.absolute.path);
  }

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _instance = this;

    final ByteData photosDb = await rootBundle.load('assets/photos.db');
    final File dbFile = _dbFile = applicationSupportDirectory.childFile('photos.db');
    if (!applicationSupportDirectory.existsSync()) {
      applicationSupportDirectory.createSync(recursive: true);
    }
    if (!dbFile.existsSync()) {
      await dbFile.writeAsBytes(photosDb.buffer.asUint8List());
    }
    _db = await createDatabase();
  }
}
