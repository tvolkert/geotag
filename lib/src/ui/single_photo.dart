import 'package:file/file.dart';
import 'package:flutter/material.dart';

import '../model/files.dart';

class SinglePhoto extends StatefulWidget {
  const SinglePhoto({
    super.key,
    required this.path,
  });

  final String path;

  @override
  State<SinglePhoto> createState() => _SinglePhotoState();
}

class _SinglePhotoState extends State<SinglePhoto> {
  String? _lastPath;

  @override
  void didUpdateWidget(covariant SinglePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _lastPath = oldWidget.path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FileSystem fs = FilesBinding.instance.fs;
    // TODO: Experiment with creating and using SynchronousFileImage provider
    // to see if it enables us to not need to use this framebuilder trick.
    return Image.file(
      fs.file(widget.path),
      frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        } else if (frame != null || _lastPath == null) {
          return child;
        } else {
          return Image.file(fs.file(_lastPath));
        }
      },
    );
  }
}
