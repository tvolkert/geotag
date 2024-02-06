import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../bindings/files.dart';
import '../model/media.dart';

class PhotoPile extends StatefulWidget {
  const PhotoPile({
    super.key,
    required this.items,
  });

  final MediaItems items;

  @override
  State<PhotoPile> createState() => _PhotoPileState();
}

class _PhotoPileState extends State<PhotoPile> {
  final List<double> _adjustments = <double>[];
  final math.Random _rand = math.Random();

  static const List<double> _rotations = <double>[0.05, -0.07];

  void _handleItemsChanged() {
    setState(() {});
  }

  void _initAdjustments() {
    _adjustments.clear();
    for (int i = 0; i < widget.items.length; i++) {
      _adjustments.add((_rand.nextInt(8) - 4) / 100);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.items.addStructureListener(_handleItemsChanged);
    _initAdjustments();
  }

  @override
  void didUpdateWidget(covariant PhotoPile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      oldWidget.items.removeStructureListener(_handleItemsChanged);
      widget.items.addStructureListener(_handleItemsChanged);
    }
    _initAdjustments();
  }

  @override
  void dispose() {
    widget.items.removeStructureListener(_handleItemsChanged);
    super.dispose();
  }

  Widget _buildPhoto(int index, MediaItem item) {
    final double rotation = index == widget.items.length - 1 ? 0 : _rotations[index];
    return Transform.rotate(
      angle: math.pi * rotation + _adjustments[index],
      child: Image.file(FilesBinding.instance.fs.file(item.photoPath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    int i = 0;
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Center(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...widget.items.map<Widget>((MediaItem item) {
              return _buildPhoto(i++, item);
            }),
          ],
        ),
      ),
    );
  }
}
