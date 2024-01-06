import 'package:flutter/foundation.dart';

import 'app.dart';

class _TaskProgress {
  _TaskProgress({required this.total});

  int completed = 0;
  int total;
}

mixin TaskBinding on AppBindingBase, ChangeNotifier {
  /// The singleton instance of this object.
  static late TaskBinding _instance;
  static TaskBinding get instance => _instance;

  _TaskProgress? _progress;

  void addTasks(int newTaskCount) {
    if (_progress == null) {
      _progress = _TaskProgress(total: newTaskCount);
    } else {
      _progress!.total += newTaskCount;
    }
    notifyListeners();
  }

  void onTaskCompleted() {
    assert(_progress != null);
    _progress!.completed++;
    if (_progress!.completed == _progress!.total) {
      _progress = null;
    }
    notifyListeners();
  }

  double? get progress {
    return _progress == null ? null : _progress!.completed / _progress!.total;
  }

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _instance = this;
  }
}
