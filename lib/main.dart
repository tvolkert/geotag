// ignore_for_file: avoid_print

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/extensions/date_time.dart';
import 'src/extensions/iterable.dart';
import 'src/model/app.dart';
import 'src/model/files.dart';
import 'src/model/gps.dart';
import 'src/model/image.dart';
import 'src/model/media.dart';
import 'src/model/tasks.dart';
import 'src/model/video.dart';
import 'src/ui/date_time_editor.dart';
import 'src/ui/photo_pile.dart';
import 'src/ui/thumbnail_list.dart';
import 'src/ui/video_player.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      await GeotagAppBinding.ensureInitialized();
      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('Caught unhandled error by zone error handler.');
      debugPrint('$error\n$stack');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  void setSelectedItems(Iterable<int> indexes);
}

class GeotagHome extends StatefulWidget {
  const GeotagHome({super.key});

  @override
  State<GeotagHome> createState() => _GeotagHomeState();

  static HomeController of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_HomeScope>()!.state;
  }
}

class _GeotagHomeState extends State<GeotagHome> implements HomeController {
  late final FocusNode _focusNode;
  final VideoPlayerPlayPauseController playPauseController = VideoPlayerPlayPauseController();
  double? _taskProgress;
  Iterable<int> _selectedIndexes = const Iterable<int>.empty();

  MediaItems get items => MediaBinding.instance.items;

  @override
  void setSelectedItems(Iterable<int> indexes) {
    setState(() {
      _selectedIndexes = indexes;
    });
  }

  void _launchFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>[
        ...JpegFile.allowedExtensions,
        ...Mp4.allowedExtensions,
      ],
      allowMultiple: true,
      lockParentWindow: true,
    );
    if (result != null) {
      TaskBinding.instance.addTasks(result.files.length);
      final Stream<MediaItem> added = items.addFiles(result.files.map<String>((PlatformFile file) {
        return file.path!;
      }));
      await for (final MediaItem _ in added) {
        TaskBinding.instance.onTaskCompleted();
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    // TODO: handle rewind & fast-forward (https://github.com/flutter/flutter/issues/140764)
    if (_selectedIndexes.length == 1 &&
        event is! KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      final MediaItem item = items[_selectedIndexes.first];
      if (item.type == MediaType.video) {
        playPauseController.playPause();
        result = KeyEventResult.handled;
      }
    }
    return result;
  }

  Future<void> _writeEditsToDisk() async {
    final MediaItems modified = items.whereModified;
    assert(modified.isNotEmpty);
    TaskBinding.instance.addTasks(modified.length);
    await for (MediaItem _ in modified.writeFilesToDisk()) {
      // TODO: cancel operation upon `dispose`
      TaskBinding.instance.onTaskCompleted();
    }
  }

  Future<void> _exportToFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Export to folder',
      lockParentWindow: true,
    );
    if (path != null) {
      TaskBinding.instance.addTasks(_selectedIndexes.length);
      await for (void _ in items.exportToFolder(path, _selectedIndexes.toList())) {
        TaskBinding.instance.onTaskCompleted();
      }
    }
  }

  Widget? _getLeading() {
    if (_taskProgress == null) {
      return null;
    }
    return Row(
      children: <Widget>[
        const CircularProgressIndicator(
          color: Color.fromARGB(255, 73, 69, 79),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: _taskProgress,
          ),
        ),
      ],
    );
  }

  int? get selectedIndex => _selectedIndexes.singleOrNull;

  MediaItem? get selectedItem => selectedIndex == null ? null : items[selectedIndex!];

  Iterable<MediaItem> get selectedItems => items.filter(_selectedIndexes);

  void _handleTasksChanged() {
    setState(() {
      _taskProgress = TaskBinding.instance.progress;
    });
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    TaskBinding.instance.addTaskListener(_handleTasksChanged);
  }

  @override
  void dispose() {
    TaskBinding.instance.removeTaskListener(_handleTasksChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScope(
      state: this,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: _getLeading(),
          actions: <Widget>[
            IconButton(
              icon: const Icon(
                Icons.add_a_photo_outlined,
                color: Colors.white,
              ),
              tooltip: 'Add photos & videos to library',
              onPressed: _launchFilePicker,
            ),
            IconButton(
              icon: Icon(
                Icons.save,
                color: _taskProgress == null && items.containsModified ? Colors.white : null,
              ),
              tooltip: 'Save all edits',
              onPressed: _taskProgress == null && items.containsModified ? _writeEditsToDisk : null,
            ),
            IconButton(
              icon: Icon(
                Icons.drive_folder_upload,
                color: _taskProgress == null ? Colors.white : null,
              ),
              tooltip: 'Export to folder',
              onPressed: _taskProgress == null ? _exportToFolder : null,
            ),
          ],
        ),
        body: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: <Widget>[
              Expanded(
                child: MainArea(
                  items: selectedItems,
                  playPauseController: playPauseController,
                ),
              ),
              const Divider(height: 1),
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
  bool updateShouldNotify(covariant _HomeScope oldWidget) => false;
}

class MainArea extends StatelessWidget {
  const MainArea({
    super.key,
    required this.items,
    required this.playPauseController,
  });

  final Iterable<MediaItem> items;
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
    this.fs = const LocalFileSystem(),
  });

  final Iterable<MediaItem> items;
  final VideoPlayerPlayPauseController playPauseController;
  final FileSystem fs;

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
            fs: fs,
          );
      }
    } else {
      result = PhotoPile(
        items: items.toList().reversed.take(3).toList().reversed,
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: result,
    );
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

  final Iterable<MediaItem> items;

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
        for (final MediaItem item in widget.items) {
          futures.add(_updateDateTime(item, newDateTime));
        }
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
        for (final MediaItem item in widget.items) {
          if (item.latlng != coords.latlng) {
            futures.add(_updateLatlng(item, coords));
          }
        }
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
      for (MediaItem item in widget.items) {
        final DateTime? dateTime = item.dateTime;
        if (dateTime != null) {
          min ??= dateTime;
          max ??= dateTime;
          min = min.earlier(dateTime);
          max = max.later(dateTime);
        }
      }
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
              Text('${ehmma.format(min)} - ${hmma.format(max)}'),
            ],
          );
        } else {
          dateTimeDisplay = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minValue - $maxValue'),
              Text('${ehmma.format(min)} - ${ehmma.format(max)}'),
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
