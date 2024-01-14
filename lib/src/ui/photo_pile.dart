import 'package:flutter/widgets.dart';

import '../model/media.dart';

class PhotoPile extends StatelessWidget {
  const PhotoPile({
    super.key,
    required this.items,
  });

  final Iterable<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    return Placeholder();
  }
}
