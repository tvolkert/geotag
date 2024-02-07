import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/media.dart';
import 'app_bar.dart';
import 'main_panel.dart';
import 'thumbnail_list.dart';
import 'video_player.dart';

abstract class HomeController {
  MediaItems get featuredItems;
  set featuredItems(MediaItems items);
}

class GeotagHome extends StatefulWidget {
  const GeotagHome({super.key});

  @override
  State<GeotagHome> createState() => _GeotagHomeState();

  static HomeController? maybeOf(BuildContext context, {bool introduceDependency = false}) {
    final _HomeScope? scope = introduceDependency
        ? context.dependOnInheritedWidgetOfExactType<_HomeScope>()
        : context.getInheritedWidgetOfExactType<_HomeScope>();
    return scope?.state;
  }
}

class _GeotagHomeState extends State<GeotagHome> implements HomeController {
  late final FocusNode _focusNode;
  final VideoPlayerPlayPauseController playPauseController = VideoPlayerPlayPauseController();
  MediaItems _featuredItems = EmptyMediaItems();

  @override
  MediaItems get featuredItems => _featuredItems;

  @override
  set featuredItems(MediaItems items) {
    setState(() {
      _featuredItems = items;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    // TODO: handle rewind & fast-forward (https://github.com/flutter/flutter/issues/140764)
    if (_featuredItems.isSingle &&
        event is! KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      final MediaItem item = _featuredItems.first;
      if (item.type == MediaType.video) {
        playPauseController.playPause();
        result = KeyEventResult.handled;
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Home');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScope(
      state: this,
      child: Scaffold(
        appBar: const GeotagAppBar(),
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: <Widget>[
              Expanded(
                child: MainPanel(
                  items: _featuredItems,
                  playPauseController: playPauseController,
                ),
              ),
              const Divider(height: 1, color: Colors.black),
              const ThumbnailList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeScope extends InheritedWidget {
  const _HomeScope({
    required super.child,
    required this.state,
  });

  final _GeotagHomeState state;

  @override
  bool updateShouldNotify(covariant _HomeScope oldWidget) {
    return state.featuredItems != oldWidget.state.featuredItems;
  }
}
