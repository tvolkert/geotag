// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math' as math;

import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/extensions/date_time.dart';
import 'src/model/app.dart';
import 'src/model/files.dart';
import 'src/model/gps.dart';
import 'src/model/media.dart';
import 'src/ui/app_bar.dart';
import 'src/ui/date_time_editor.dart';
import 'src/ui/photo_pile.dart';
import 'src/ui/thumbnail_list.dart';
import 'src/ui/video_player.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      await GeotagAppBinding.ensureInitialized();
      runApp(const Geotagger());
    },
    (Object error, StackTrace stack) {
      debugPrint('Caught unhandled error by zone error handler.');
      debugPrint('$error\n$stack');
    },
  );
}

class Geotagger extends StatelessWidget {
  const Geotagger({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Geotagger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GeotagHome(),
    );
  }
}

abstract class HomeController {
  MediaItems get featuredItems;
  set featuredItems(MediaItems items);
}

class GeotagHome extends StatefulWidget {
  const GeotagHome({super.key});

  @override
  State<GeotagHome> createState() => _GeotagHomeState();

  static HomeController of(BuildContext context, {bool introduceDependency = false}) {
    if (introduceDependency) {
      return context.dependOnInheritedWidgetOfExactType<_HomeScope>()!.state;
    } else {
      return context.getInheritedWidgetOfExactType<_HomeScope>()!.state;
    }
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
    _focusNode = FocusNode();
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
                child: MainArea(
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

class MainArea extends StatelessWidget {
  const MainArea({
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
          child: MainImage(
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

class MainImage extends StatelessWidget {
  const MainImage({
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
        items: items.where(LastNMediaItemFilter(3)),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: result,
    );
  }
}

final class LastNMediaItemFilter extends MediaItemFilter {
  LastNMediaItemFilter(this.n) : assert(n >= 0);

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

class MetadataPanel extends StatefulWidget {
  const MetadataPanel(this.items, {super.key});

  final MediaItemsView items;

  @override
  State<MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends State<MetadataPanel> {
  bool _isEditingLatlng = false;
  late TextEditingController latlngController;
  late FocusNode dateTimeFocusNode;
  late FocusNode latlngFocusNode;
  late final WebViewController webViewController;

  static final DateFormat mmmmdyyyy = DateFormat('MMM d, yyyy');
  static final DateFormat ehmma = DateFormat('E, h:mm a');
  static final DateFormat hmma = DateFormat('h:mm a');

  Future<void> _updateLatlngUiElements({bool firstRun = false}) async {
    if (widget.items.isEmpty) {
      latlngController.text = '';
    } else if (widget.items.isSingle) {
      final MediaItem item = widget.items.single;
      String? currentUrl = await webViewController.currentUrl();
      if (item.hasLatlng) {
        final GpsCoordinates coords = item.coords!;
        latlngController.text = '${coords.latitude}, ${coords.longitude}';
        if (firstRun || currentUrl == null) {
          webViewController.loadRequest(
            Uri.parse('https://tvolkert.dev/map.html?initial=${coords.latitude},${coords.longitude}'),
          );
        } else {
          webViewController.runJavaScript('window.rePin("${coords.latitude},${coords.longitude}")');
        }
      } else {
        latlngController.text = '';
        webViewController.loadRequest(Uri.parse('https://tvolkert.dev/map.html?initial=0,0'));
      }
    } else {
      latlngController.text = '';
    }
    setState(() {});
  }

  Future<void> _updateDateTime(MediaItem item, DateTime dateTime) async {
    item
        ..dateTimeOriginal = dateTime
        ..dateTimeDigitized = dateTime
        ..isModified = true
        ..lastModified = DateTime.now()
        ;
    await item.commit();
  }

  void _handleEditDateTime() async {
    if (widget.items.isEmpty) {
      return;
    }

    DateTime? initialDateTime = widget.items.isSingle ? widget.items.single.dateTime : null;
    DateTime? newDateTime = await DateTimeEditorDialog.show(context, initialDateTime);
    if (newDateTime != null) {
      if (widget.items.isSingle) {
        await _updateDateTime(widget.items.single, newDateTime);
      } else {
        final List<Future<void>> futures = <Future<void>>[];
        widget.items.forEach((MediaItem item) {
          futures.add(_updateDateTime(item, newDateTime));
        });
        await Future.wait<void>(futures);
      }
      setState(() {});
    }
  }

  void _handleLatlngSubmitted(String value) {
    assert(value == latlngController.text);
    setIsEditingLatlng(false);
  }

  void _handleFocusChanged() {
    setIsEditingLatlng(FocusManager.instance.primaryFocus == latlngFocusNode);
  }

  void setIsEditingLatlng(bool value) {
    if (value != _isEditingLatlng) {
      _isEditingLatlng = value;
      if (!value) {
        _saveLatlngEdits();
      }
    }
  }

  Future<void> _updateLatlng(MediaItem item, GpsCoordinates coords) async {
    item
        ..latlng = coords.latlng
        ..isModified = true
        ..lastModified = DateTime.now()
        ;
    await item.commit();
  }

  Future<void> _saveLatlngEdits() async {
    if (widget.items.isEmpty || latlngController.text.isEmpty) {
      return;
    }

    try {
      final GpsCoordinates coords = GpsCoordinates.fromString(latlngController.text);
      if (widget.items.isSingle) {
        final MediaItem item = widget.items.single;
        if (item.latlng != coords.latlng) {
          await _updateLatlng(item, coords);
          _updateLatlngUiElements();
        }
      } else {
        final List<Future<void>> futures = <Future<void>>[];
        widget.items.forEach((MediaItem item) {
          if (item.latlng != coords.latlng) {
            futures.add(_updateLatlng(item, coords));
          }
        });
        await Future.wait<void>(futures);
        _updateLatlngUiElements();
      }
    } on FormatException {
      print('invalid gps coordinates');
    }
  }

  Widget _buildSingleDateTimeDisplay(DateTime? value) {
    if (value == null) {
      return const Text('unset', style: TextStyle(fontStyle: FontStyle.italic));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mmmmdyyyy.format(value)),
        Text(ehmma.format(value)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    latlngController = TextEditingController();
    dateTimeFocusNode = FocusNode();
    latlngFocusNode = FocusNode();
    FocusManager.instance.addListener(_handleFocusChanged);
    _updateLatlngUiElements(firstRun: true);
    webViewController = WebViewController()
      ..clearCache()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            // TODO: update GPS coordinates
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ;
  }

  @override
  void didUpdateWidget(covariant MetadataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLatlngUiElements(firstRun: false);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    latlngFocusNode.dispose();
    dateTimeFocusNode.dispose();
    latlngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container();
    }

    final Widget dateTimeDisplay;
    if (widget.items.isSingle) {
      dateTimeDisplay = _buildSingleDateTimeDisplay(widget.items.single.dateTime);
    } else {
      DateTime? min, max;
      widget.items.forEach((MediaItem item) {
        final DateTime? dateTime = item.dateTime;
        if (dateTime != null) {
          min ??= dateTime;
          max ??= dateTime;
          min = min!.earlier(dateTime);
          max = max!.later(dateTime);
        }
      });
      if (min == max) {
        dateTimeDisplay = _buildSingleDateTimeDisplay(min);
      } else {
        assert(min != null);
        assert(max != null);
        final String minValue = mmmmdyyyy.format(min!);
        final String maxValue = mmmmdyyyy.format(max!);
        if (minValue == maxValue) {
          dateTimeDisplay = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(minValue),
              Text('${ehmma.format(min!)} - ${hmma.format(max!)}'),
            ],
          );
        } else {
          dateTimeDisplay = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minValue - $maxValue'),
              Text('${ehmma.format(min!)} - ${ehmma.format(max!)}'),
            ],
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Details',
            style: TextStyle(
              color: Color(0xff606367),
              fontFeatures: <FontFeature>[FontFeature.enable('smcp')],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.calendar_today_rounded),
              const SizedBox(width: 30),
              dateTimeDisplay,
              Expanded(child: Container()),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _handleEditDateTime,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.photo_outlined),
              const SizedBox(width: 30),
              widget.items.isSingle
                  ? SelectableText(widget.items.single.path.split('/').last)
                  : Text(
                    '${widget.items.length} items',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
            ],
          ),
        ),
        Center(
          child: TextField(
            controller: latlngController,
            focusNode: latlngFocusNode,
            onSubmitted: _handleLatlngSubmitted,
          ),
        ),
        Expanded(
          child: WebViewWidget(controller: webViewController),
        ),
      ],
    );
  }
}
