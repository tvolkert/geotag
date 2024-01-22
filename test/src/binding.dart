import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/model/app.dart';
import 'package:geotag/src/model/db.dart';
import 'package:geotag/src/model/files.dart';
import 'package:geotag/src/model/media.dart';
import 'package:geotag/src/model/tasks.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

import 'db.dart';

class TestGeotagAppBinding extends AppBindingBase
    with FilesBinding, DatabaseBinding, MediaBinding, TaskBinding {

  final FileSystem _fs = MemoryFileSystem.test();

  static final sqflite.Database _db = FakeDatabase();
  static Future<sqflite.Database> _getFakeDatabase() async => _db;

  @override
  FileSystem get fs => _fs;

  @override
  @protected
  Future<Directory> createAppSupportDirectory() async {
    return fs.directory('/support')..createSync();
  }

  @override
  Future<DbResults> getAllMediaItems() async => DbResults.empty(growable: true);

  @override
  @protected
  Future<sqflite.Database> createDatabase() {
    return _getFakeDatabase();
  }

  @override
  DatabaseFactory get databaseFactory => _getFakeDatabase;

  static Future<void> ensureInitialized() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TestGeotagAppBinding().initialized;
  }
}
