import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

typedef StreamCallback<M, R> = Stream<R> Function(M message);

class Isolates {
  static Stream<R> stream<M, R extends Object>(StreamCallback<M, R> worker, M message, {String? debugLabel}) {
    debugLabel ??= kReleaseMode ? 'compute' : worker.toString();
    return _stream(() {
      return worker(message);
    }, debugName: debugLabel);
  }

  static Stream<R> _stream<M, R extends Object>(Stream<R> Function() worker, {required String debugName}) {
    final StreamController<R> controller = StreamController<R>();
    final RawReceivePort resultPort = RawReceivePort();
    resultPort.handler = (dynamic message) {
      if (message == null) {
        // onExit handler message, isolate terminated without sending result.
        controller.addError(RemoteError('Computation ended without result', ''));
      }

      final _StreamEvent event = message as _StreamEvent;
      switch (event.type) {
        case _StreamEventType.data:
          controller.add(event.payload as R);
        case _StreamEventType.error:
          controller.addError(event.payload as Object, event.stackTrace);
        case _StreamEventType.done:
          controller.close();
          resultPort.close();
      }
    };
    try {
      Isolate.spawn<_RemoteRunner<R>>(
        _RemoteRunner._remoteExecute,
        _RemoteRunner<R>(worker, resultPort.sendPort),
        onError: resultPort.sendPort,
        onExit: resultPort.sendPort,
        errorsAreFatal: false,
        debugName: debugName,
      )
      .catchError((dynamic error, StackTrace stack) {
        // Sending the computation failed asynchronously.
        // Do not expect a response, report the error asynchronously.
        resultPort.close();
        controller.addError(error, stack);
        controller.close();
      });
    } on Object {
      // Sending the computation failed synchronously.
      // This is not expected to happen, but if it does,
      // the synchronous error is respected and rethrown synchronously.
      resultPort.close();
      rethrow;
    }
    return controller.stream;
  }
}

enum _StreamEventType {
  data,
  done,
  error,
}

class _StreamEvent {
  const _StreamEvent(this.type, [this.payload, this.stackTrace]);

  final _StreamEventType type;
  final Object? payload;
  final StackTrace? stackTrace;
}

/// Parameter object used by [Isolates.stream].
///
/// The [_remoteExecute] function is run in a new isolate with a
/// [_RemoteRunner] object as argument.
final class _RemoteRunner<T> {
  /// User worker function to run.
  final Stream<T> Function() worker;

  /// Port to send isolate stream events on.
  ///
  /// Multiple objects may be sent on this port.
  ///
  /// If the value is `null`, it is sent by the isolate's "on-exit" handler
  /// when the isolate terminates without otherwise sending value.
  ///
  /// Otherwise, values will be of type [_StreamEvent], and the event type
  /// will determine if the stream has sent data, an error, or has closed.
  final SendPort resultPort;

  _RemoteRunner(this.worker, this.resultPort);

  /// Run in a new isolate to get the result of [worker].
  ///
  /// The result is sent back on [resultPort] as a single-element list.
  /// A two-element list sent on the same port is an error result.
  /// When sent by this function, it's always an object and a [StackTrace].
  /// (The same port listens on uncaught errors from the isolate, which
  /// sends two-element lists containing [String]s instead).
  static void _remoteExecute<T>(_RemoteRunner<T> runner) {
    runner._run();
  }

  void _handleData(T data) {
    resultPort.send(_StreamEvent(_StreamEventType.data, data));
  }

  void _handleError(Object error, StackTrace stackTrace) {
    resultPort.send(_StreamEvent(_StreamEventType.error, error, stackTrace));
  }

  void _handleDone() {
    Isolate.exit(resultPort, const _StreamEvent(_StreamEventType.done));
  }

  void _run() async {
    try {
      final Stream<T> stream = worker();
      stream.listen(_handleData, onError: _handleError, onDone: _handleDone);
    } catch (error, stackTrace) {
      Isolate.exit(resultPort, _StreamEvent(_StreamEventType.error, error, stackTrace));
    }
  }
}
