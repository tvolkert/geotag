import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'db.dart';
import 'debug.dart';
import 'files.dart';
import 'media.dart';
import 'tasks.dart';

class GeotagAppBinding extends AppBindingBase
    with FilesBinding, DatabaseBinding, MediaBinding, TaskBinding {
  /// Creates and initializes the application binding if necessary.
  ///
  /// Applications should call this method before calling [runApp].
  static Future<void> ensureInitialized() async {
    // [AppBinding.initInstances] may rely on things like [ServicesBinding].
    WidgetsFlutterBinding.ensureInitialized();
    await GeotagAppBinding().initialized;
  }
}

abstract class AppBindingBase {
  /// Default abstract constructor for application bindings.
  ///
  /// First calls [initInstances] to have bindings initialize their
  /// instance pointers and other state.
  AppBindingBase() {
    developer.Timeline.startSync('App initialization');

    assert(!_debugInitialized || debugAllowBindingReinitialization);
    _initialized = initInstances();
    assert(_debugInitialized);

    developer.postEvent('Geotag.AppInitialization', <String, String>{});
    _initialized.whenComplete(() {
      developer.Timeline.finishSync();
    });
  }

  static bool _debugInitialized = false;

  /// A future that completes once this app binding has been fully initialized.
  late Future<void> _initialized;
  Future<void> get initialized => _initialized;

  /// The initialization method. Subclasses override this method to hook into
  /// the app. Subclasses must call `await super.initInstances()` as the first
  /// line in their method.
  ///
  /// By convention, if the service is to be provided as a singleton, it should
  /// be exposed as `MixinClassName.instance`, a static getter that returns
  /// `MixinClassName._instance`, a static field that is set by
  /// `initInstances()`.
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    assert(!_debugInitialized || debugAllowBindingReinitialization);
    assert(() {
      _debugInitialized = true;
      return true;
    }());
  }

  @override
  String toString() => '<${objectRuntimeType(this, 'AppBindingBase')}>';
}
