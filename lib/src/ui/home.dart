import 'package:flutter/material.dart';

import '../model/media.dart';
import 'app_bar.dart';
import 'main_panel.dart';
import 'thumbnail_list.dart';

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
  MediaItems _featuredItems = EmptyMediaItems();

  @override
  MediaItems get featuredItems => _featuredItems;

  @override
  set featuredItems(MediaItems items) {
    setState(() {
      _featuredItems = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScope(
      state: this,
      child: Scaffold(
        appBar: const GeotagAppBar(),
        body: Column(
          children: <Widget>[
            Expanded(
              child: MainPanel(
                items: _featuredItems,
              ),
            ),
            const Divider(height: 1, color: Colors.black),
            const ThumbnailList(),
          ],
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
