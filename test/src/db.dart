import 'package:geotag/src/bindings/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;

typedef DbTables = Map<String, DbResults>;

class FakeDatabase implements sqflite.Database {
  final DbTables _tables = DbTables();
  int _nextId = 1;

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
    assert(nullColumnHack == null);
    assert(conflictAlgorithm == null);
    assert(!values.containsKey('ITEM_ID'));
    final int id = _nextId++;
    final DbResults rows = _tables.putIfAbsent(table, () => DbResults.empty(growable: true));
    rows.add(DbRow.from(values)..['ITEM_ID'] = id);
    return Future<int>.value(id);
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) {
    final DbResults? rows = _tables[table];
    assert(rows != null);
    // TODO: implement update
    throw UnimplementedError();
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    if (where == null) {
      DbResults? removedRows = _tables.remove(table);
      return Future<int>.value(removedRows?.length ?? 0);
    } else if (_tables.containsKey(table)) {
      assert(whereArgs != null);
      assert(whereArgs!.length == 1);
      final RegExp wherePattern = RegExp(r'^([a-zA-Z]+) = \?$');
      assert(wherePattern.hasMatch(where));
      final RegExpMatch match = wherePattern.firstMatch(where)!;
      final String field = match.group(1)!;
      final DbResults rows = _tables[table]!;
      bool shouldRemove(DbRow row) => row[field] == whereArgs!.single;
      int result = rows.where(shouldRemove).length;
      rows.removeWhere(shouldRemove);
      return Future<int>.value(result);
    } else {
      return Future<int>.value(0);
    }
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
