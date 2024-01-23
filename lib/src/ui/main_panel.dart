import 'package:flutter/material.dart';

import '../model/media.dart';
import 'metadata_panel.dart';
import 'preview_panel.dart';
import 'video_player.dart';

class MainPanel extends StatelessWidget {
  const MainPanel({
    super.key,
    required this.items,
    required this.playPauseController,
  });

  final MediaItems items;
  final VideoPlayerPlayPauseController playPauseController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: PreviewPanel(
            items: items,
            playPauseController: playPauseController,
          ),
        ),
        SizedBox(
          width: 500,
          child: MetadataPanel(items),
        ),
      ],
    );
  }
}
