import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/media.dart';
import 'app.dart';
import 'db.dart';

mixin MediaBinding on AppBindingBase, DatabaseBinding {
  /// The singleton instance of this object.
  static late MediaBinding _instance;
  static MediaBinding get instance => _instance;

  late RootMediaItems _items;
  RootMediaItems get items => _items;

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
