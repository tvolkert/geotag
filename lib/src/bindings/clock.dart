import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'app.dart';

import 'package:clock/clock.dart';

typedef TimestampFactory = DateTime Function();

mixin ClockBinding on AppBindingBase {
  /// The singleton instance of this object.
  static late ClockBinding _instance;
  static ClockBinding get instance => _instance;

  Clock get clock => const Clock();

  @nonVirtual
  TimestampFactory get now => clock.now;

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _instance = this;
  }
}
