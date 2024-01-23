import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/media.dart';
import 'photo_pile.dart';
import 'single_photo.dart';
import 'video_player.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({
    super.key,
    required this.items,
    required this.playPauseController,
  });

  final MediaItems items;
  final VideoPlayerPlayPauseController playPauseController;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container();
    }

    final Widget result;
    if (items.isSingle) {
      MediaItem item = items.single;
      switch (item.type) {
        case MediaType.photo:
          result = SinglePhoto(path: item.photoPath);
        case MediaType.video:
          return VideoPlayer(
            item: item,
            playPauseController: playPauseController,
          );
      }
    } else {
      result = PhotoPile(
        items: items.where(_LastNMediaItemFilter(3)),
      );
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
}
