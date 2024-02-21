import 'package:file/file.dart';

extension FileSystemEntityExtensions on FileSystemEntity {
  String get basenameWithoutExtension => fileSystem.path.basenameWithoutExtension(path);

  String get extension => fileSystem.path.extension(path);
}
