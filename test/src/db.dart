import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

class FakeDatabase implements sqflite.Database {
  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    // TODO: implement insert
    throw UnimplementedError();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    // TODO: implement update
    throw UnimplementedError();
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    // TODO: implement query
    throw UnimplementedError();
  }
}
