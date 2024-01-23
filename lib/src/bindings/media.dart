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

  // TODO: change to be keyed off ITEM_ID instead of PATH
  final Map<String, MediaNotifier> _itemNotifiers = <String, MediaNotifier>{};

  late RootMediaItems _items;
  RootMediaItems get items => _items;

  void addItemListener(String path, VoidCallback listener) {
    final MediaNotifier notifier = _itemNotifiers.putIfAbsent(path, () => MediaNotifier());
    notifier.addListener(listener);
  }

  void removeItemListener(String path, VoidCallback listener) {
    final MediaNotifier? notifier = _itemNotifiers[path];
    assert(notifier != null);
    notifier!.removeListener(listener);
    if (!notifier.hasListeners) {
      notifier.dispose();
      _itemNotifiers.remove(path);
    }
  }

  void notifyItemChanged(String path) {
    _itemNotifiers[path]?.notifyListeners();
  }

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
