import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'app.dart';

mixin FilesBinding on AppBindingBase {
  /// The singleton instance of this object.
  static late FilesBinding _instance;
  static FilesBinding get instance => _instance;

  final FileSystem fs = const LocalFileSystem();

  late final Directory _appSupportDirectory;
  Directory get applicationSupportDirectory => _appSupportDirectory;

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _appSupportDirectory = fs.directory(await path_provider.getApplicationSupportDirectory());
    _instance = this;
  }
}
