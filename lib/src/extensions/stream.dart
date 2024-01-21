import 'dart:async';

extension StreamExtensions<T> on Stream<T> {
  Future<void> listenAndWait(
    void Function(T data) onData, {
    required void Function(Object error, StackTrace stack) onError,
  }) {
    final Completer<void> completer = Completer<void>();
    listen(onData, onError: onError, onDone: completer.complete);
    return completer.future;
  }
}
