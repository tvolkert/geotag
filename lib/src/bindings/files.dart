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

  late final Directory _appSupportDirectory;
  Directory get applicationSupportDirectory => _appSupportDirectory;

  FileSystem get fs => const LocalFileSystem();

  @protected
  Future<Directory> createAppSupportDirectory() async {
    return fs.directory(await path_provider.getApplicationSupportDirectory());
  }

  @override
  @protected
  @mustCallSuper
  Future<void> initInstances() async {
    await super.initInstances();
    _appSupportDirectory = await createAppSupportDirectory();
    _instance = this;
  }
}
