import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/files.dart';
import '../model/media.dart';

class PhotoPile extends StatelessWidget {
  const PhotoPile({
    super.key,
    required this.items,
  });

  final Iterable<MediaItem> items;

  static const List<double> _rotations = <double>[0.05, -0.1];

  @override
  Widget build(BuildContext context) {
    int i = 0;
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: Stack(
          children: <Widget>[
            ...items.take(items.length - 1).map<Widget>((MediaItem item) {
              final double rotation = _rotations[i++];
              return Transform.rotate(
                angle: math.pi * rotation,
                child: Image.file(FilesBinding.instance.fs.file(item.photoPath)),
              );
            }),
            Image.file(FilesBinding.instance.fs.file(items.last.photoPath)),
          ],
        ),
      ),
    );
  }
}
