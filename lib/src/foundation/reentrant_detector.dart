class ReentrantDetector {
  bool _flag = false;

  /// Whether the currently executing code is the result of a call to
  /// [runCallback] or [runAsyncCallback].
  bool get isReentrant => _flag;

  /// Runs and returns the result of the specified callback.
  ///
  /// Code running in the callback (or in functions called by the callback) will
  /// see an [isReentrant] value of true.
  T runCallback<T>(T Function() callback) {
    assert(!_flag);
    _flag = true;
    try {
      return callback();
    } finally {
      _flag = false;
    }
  }

  /// Runs and returns the result of the specified callback.
  ///
  /// Code running in the callback (or in functions called by the callback) will
  /// see an [isReentrant] value of true.
  Future<T> runAsyncCallback<T>(Future<T> Function() callback) async {
    assert(!_flag);
    _flag = true;
    try {
      return await callback();
    } finally {
      _flag = false;
    }
  }
}
