import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/media.dart';
import 'photo_pile.dart';
import 'single_photo.dart';
import 'video_player.dart';

class PreviewPanel extends StatefulWidget {
  const PreviewPanel({
    super.key,
    required this.items,
  });

  final MediaItems items;

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  late MediaItems _last3;

  void _handleItemsChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.items.addStructureListener(_handleItemsChanged);
    _last3 = widget.items.where(_LastNMediaItemFilter(3));
  }

  @override
  void didUpdateWidget(covariant PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      oldWidget.items.removeStructureListener(_handleItemsChanged);
      _last3 = widget.items.where(_LastNMediaItemFilter(3));
      widget.items.addStructureListener(_handleItemsChanged);
    }
  }

  @override
  void dispose() {
    widget.items.removeStructureListener(_handleItemsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container();
    }

    final Widget result;
    if (widget.items.isSingle) {
      MediaItem item = widget.items.single;
      switch (item.type) {
        case MediaType.photo:
          result = SinglePhoto(path: item.photoPath);
        case MediaType.video:
          return VideoPlayer(item: item);
      }
    } else {
      result = PhotoPile(items: _last3);
    }

    return ColoredBox(
      color: Colors.black,
      child: result,
    );
  }
}

final class _LastNMediaItemFilter extends MediaItemFilter {
  _LastNMediaItemFilter(this.n) : assert(n >= 0);

  final int n;

  @override
  Iterable<MediaItem> apply(List<MediaItem> source) {
    List<MediaItem> result = <MediaItem>[];
    for (int i = math.max(0, source.length - n); i < source.length; i++) {
      result.add(source[i]);
    }
    return result;
  }

  @override
  String toString() => '<last $n>';
}
