// ignore_for_file: avoid_print

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/model/app.dart';
import 'src/model/gps.dart';
import 'src/model/media.dart';
import 'src/model/tasks.dart';
import 'src/ui/date_time_editor.dart';
import 'src/ui/thumbnail_list.dart';
import 'src/ui/video_player.dart';

void main() async {
  await GeotagAppBinding.ensureInitialized();
  runApp(const MyApp());
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
  Iterable<int> _selectedItems = const Iterable<int>.empty();

  MediaItems get items => MediaBinding.instance.items;

  @override
  void setSelectedItems(Iterable<int> indexes) {
    setState(() {
      _selectedItems = indexes;
    });
  }

  void _launchFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowedExtensions: ['jpg', 'jpeg', /*'png', 'gif', 'webp', */'mp4', 'mov'],
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
    if (_selectedItems.length == 1 &&
        event is! KeyUpEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      final MediaItem item = items[_selectedItems.first];
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
      TaskBinding.instance.addTasks(items.length);
      await for (void _ in items.exportToFolder(path)) {
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

  int? get selectedIndex => _selectedItems.singleOrNull;

  MediaItem? get selectedItem => selectedIndex == null ? null : items[selectedIndex!];

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
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'Add photos & videos to library',
              onPressed: _launchFilePicker,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save all edits',
              onPressed: _taskProgress == null && items.containsModified ? _writeEditsToDisk : null,
            ),
            IconButton(
              icon: const Icon(Icons.drive_folder_upload),
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
                  item: selectedItem,
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
    required this.item,
    required this.playPauseController,
  });

  final MediaItem? item;
  final VideoPlayerPlayPauseController playPauseController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: MainImage(
            item: item,
            playPauseController: playPauseController,
          ),
        ),
        SizedBox(
          width: 500,
          child: MetadataPanel(item),
        ),
      ],
    );
  }
}

class MainImage extends StatelessWidget {
  const MainImage({
    super.key,
    required this.item,
    required this.playPauseController,
    this.fs = const LocalFileSystem(),
  });

  final MediaItem? item;
  final VideoPlayerPlayPauseController playPauseController;
  final FileSystem fs;

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Container();
    }

    Widget result;
    switch (item!.type) {
      case MediaType.photo:
        result = Image.file(fs.file(item!.photoPath));
      case MediaType.video:
        return VideoPlayer(
          item: item!,
          playPauseController: playPauseController,
          fs: fs,
        );
    }
    return ColoredBox(
      color: Colors.black,
      child: result,
    );
  }
}

class MetadataPanel extends StatefulWidget {
  const MetadataPanel(this.item, {super.key});

  final MediaItem? item;

  @override
  State<MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends State<MetadataPanel> {
  bool _isEditingLatlng = false;
  late TextEditingController latlngController;
  late FocusNode dateTimeFocusNode;
  late FocusNode latlngFocusNode;
  late final WebViewController webViewController;

  Future<void> _updateRow({bool firstRun = false}) async {
    if (widget.item == null) {
      latlngController.text = '';
    } else {
      String? currentUrl = await webViewController.currentUrl();
      if (widget.item!.hasLatlng) {
        final GpsCoordinates coords = widget.item!.coords!;
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
    }
    setState(() {});
  }

  void _handleEditDateTime() async {
    DateTime? newDateTime = await DateTimeEditorDialog.show(context, widget.item!.dateTime);
    if (newDateTime != null) {
      widget.item!
          ..dateTimeOriginal = newDateTime
          ..dateTimeDigitized = newDateTime
          ..isModified = true
          ..lastModified = DateTime.now()
          ;
      await widget.item!.commit();
      _updateRow();
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
        _saveEdits();
      }
    }
  }

  Future<void> _saveEdits() async {
    try {
      final GpsCoordinates coords = GpsCoordinates.fromString(latlngController.text);
      widget.item!
          ..latlng = coords.latlng
          ..isModified = true
          ..lastModified = DateTime.now()
          ;
      await widget.item!.commit();
      _updateRow();
    } on FormatException {
      print('invalid gps coordinates');
    }
  }

  @override
  void initState() {
    super.initState();
    latlngController = TextEditingController();
    dateTimeFocusNode = FocusNode();
    latlngFocusNode = FocusNode();
    FocusManager.instance.addListener(_handleFocusChanged);
    _updateRow(firstRun: true);
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
    _updateRow(firstRun: false);
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
    if (widget.item == null) {
      return Container();
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM d, yyyy').format(widget.item!.dateTime ?? DateTime.now())),
                  Text(DateFormat('E, h:mm a').format(widget.item!.dateTime ?? DateTime.now())),
                ],
              ),
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
              SelectableText(widget.item!.path.split('/').last),
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
