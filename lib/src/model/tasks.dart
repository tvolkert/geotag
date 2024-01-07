import 'package:flutter/foundation.dart';

import 'app.dart';

class _TaskProgress {
  _TaskProgress({required this.total});

  int completed = 0;
  int total;
}

class _TaskNotifier extends Object with ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

mixin TaskBinding on AppBindingBase {
  /// The singleton instance of this object.
  static late TaskBinding _instance;
  static TaskBinding get instance => _instance;

  final _TaskNotifier _notifier = _TaskNotifier();
  _TaskProgress? _progress;

  void addTaskListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  void removeTaskListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  void addTasks(int newTaskCount) {
    if (_progress == null) {
      _progress = _TaskProgress(total: newTaskCount);
    } else {
      _progress!.total += newTaskCount;
    }
    _notifier.notifyListeners();
  }

  void onTaskCompleted() {
    assert(_progress != null);
    _progress!.completed++;
    if (_progress!.completed == _progress!.total) {
      _progress = null;
    }
    _notifier.notifyListeners();
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
