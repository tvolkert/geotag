// ignore_for_file: avoid_print

import 'dart:async';

import 'package:chicago/chicago.dart' show isPlatformCommandKeyPressed, isShiftKeyPressed, ListViewSelectionController, SelectMode, Span;
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/model/app.dart';
import 'src/model/db.dart';
import 'src/model/gps.dart';
import 'src/ui/confirm_delete_files.dart';
import 'src/ui/date_time_editor.dart';
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
      home: const MyHomePage(),
    );
  }
}

abstract class HomeController {
}

class _TaskProgress {
  _TaskProgress({required this.total});

  int completed = 0;
  int total;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();

  static HomeController of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_HomeScope>()!.state;
  }
}

class _MyHomePageState extends State<MyHomePage> implements HomeController {
  late final ScrollController scrollController;
  late final ListViewSelectionController _selectionController;
  late final FocusNode _focusNode;
  final ScrollToVisibleController scrollToVisibleController = ScrollToVisibleController();
  final VideoPlayerPlayPauseController playPauseController = VideoPlayerPlayPauseController();
  DbResults? photos;
  _TaskProgress? taskProgress;

  static const double listViewItemExtent = 175;

  void _launchFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowedExtensions: ['jpg', 'jpeg', /*'png', 'gif', 'webp', */'mp4', 'mov'],
      allowMultiple: true,
      lockParentWindow: true,
    );
    if (result != null) {
      assert(photos != null);
      _addTasks(result.files.length);
      final Stream<DbRow> rows = photos!.addFiles(result.files.map<String>((PlatformFile file) {
        return file.path!;
      }));
      await for (final DbRow _ in rows) {
        _handleTaskCompleted();
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  bool get hasUnsavedEdits => photos?.where((DbRow row) => row.isModified).isNotEmpty ?? false;

  void _addTasks(int newTaskCount) {
    setState(() {
      if (taskProgress == null) {
        taskProgress = _TaskProgress(total: newTaskCount);
      } else {
        taskProgress!.total += newTaskCount;
      }
    });
  }

  void _handleTaskCompleted() {
    assert(taskProgress != null);
    if (mounted) {
      setState(() {
        taskProgress!.completed++;
        if (taskProgress!.completed == taskProgress!.total) {
          taskProgress = null;
        }
      });
    }
  }

  // Handle rewind & fast-forward (https://github.com/flutter/flutter/issues/140764)
  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    if (photos != null && _selectionController.selectedItems.isNotEmpty && event is! KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
        () async {
          if (await ConfirmDeleteFilesDialog.show(context)) {
            _deleteItems(_selectionController.selectedItems.toList());
          }
        }();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final int newSelectedIndex = _selectionController.firstSelectedIndex - 1;
        if (newSelectedIndex >= 0) {
          setState(() {
            _selectionController.selectedIndex = newSelectedIndex;
            scrollToVisibleController.notifyListener(newSelectedIndex, ScrollPositionAlignmentPolicy.keepVisibleAtStart);
          });
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final int newSelectedIndex = _selectionController.lastSelectedIndex + 1;
        if (newSelectedIndex < photos!.length) {
          setState(() {
            _selectionController.selectedIndex = newSelectedIndex;
            scrollToVisibleController.notifyListener(newSelectedIndex, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
          });
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (_selectionController.selectedItems.length == 1) {
          final DbRow row = photos![_selectionController.firstSelectedIndex];
          if (row.type == MediaType.video) {
            playPauseController.playPause();
            result = KeyEventResult.handled;
          }
        }
      }
    }
    return result;
  }

  Future<void> _writeEditsToDisk() async {
    assert(photos != null);
    final DbResults modifiedPhotos = photos!.where((DbRow row) => row.isModified).toList();
    assert(modifiedPhotos.isNotEmpty);
    _addTasks(modifiedPhotos.length);
    await for (DbRow _ in modifiedPhotos.writeFilesToDisk()) {
      // TODO: cancel operation upon `dispose`
      _handleTaskCompleted();
    }
  }

  Future<void> _exportToFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Export to folder',
      lockParentWindow: true,
    );
    if (path != null && photos != null) {
      _addTasks(photos!.length);
      await for (void _ in photos!.exportToFolder(path)) {
        _handleTaskCompleted();
      }
    }
  }

  Widget? _getLeading() {
    if (taskProgress == null) {
      return null;
    }
    return Row(
      children: <Widget>[
        const CircularProgressIndicator(
          color: Color.fromARGB(255, 73, 69, 79),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: taskProgress!.completed / taskProgress!.total,
          ),
        ),
      ],
    );
  }

  int? get selectedIndex => _selectionController.selectedItems.singleOrNull;

  DbRow? get selectedRow => selectedIndex == null ? null : photos?[selectedIndex!];

  Future<void> _deleteItems(Iterable<int> indexes) async {
    assert(photos != null);
    assert(indexes.length <= photos!.length);
    assert(indexes.every((int index) => index < photos!.length));
    _addTasks(indexes.length);
    setState(() {
      final newNextIndex = _selectionController.lastSelectedIndex + 1 - indexes.length;
      if (newNextIndex < photos!.length - indexes.length) {
        _selectionController.selectedIndex = newNextIndex;
      } else if (_selectionController.firstSelectedIndex > 0) {
        _selectionController.selectedIndex = _selectionController.firstSelectedIndex - 1;
      } else {
        _selectionController.clearSelection();
        _focusNode.unfocus();
      }
    });
    await for (DbRow _ in photos!.deleteFiles(indexes)) {
      _handleTaskCompleted();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    _selectionController = ListViewSelectionController(selectMode: SelectMode.multi);
    _focusNode = FocusNode();
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      () async {
        photos = await DatabaseBinding.instance.getAllPhotos();
        setState(() {});
      }();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _selectionController.dispose();
    scrollController.dispose();
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
              onPressed: taskProgress == null && hasUnsavedEdits ? _writeEditsToDisk : null,
            ),
            IconButton(
              icon: const Icon(Icons.drive_folder_upload),
              tooltip: 'Export to folder',
              onPressed: taskProgress == null ? _exportToFolder : null,
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: MainArea(
                row: selectedRow,
                playPauseController: playPauseController,
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: listViewItemExtent,
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: _handleKeyEvent,
                  child: ListView.builder(
                    itemExtent: listViewItemExtent,
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: photos?.length ?? 0,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.all(5),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isShiftKeyPressed()) {
                                final int startIndex = _selectionController.firstSelectedIndex;
                                if (startIndex == -1) {
                                  _selectionController.addSelectedIndex(index);
                                } else {
                                  final int endIndex = _selectionController.lastSelectedIndex;
                                  final Span range = Span(index, index > startIndex ? startIndex : endIndex);
                                  _selectionController.selectedRange = range;
                                }
                              } else if (isPlatformCommandKeyPressed()) {
                                if (_selectionController.isItemSelected(index)) {
                                  _selectionController.removeSelectedIndex(index);
                                } else {
                                  _selectionController.addSelectedIndex(index);
                                }
                              } else {
                                _selectionController.selectedIndex = index;
                              }
                              _focusNode.requestFocus();
                            });
                          },
                          child: Stack(
                            fit: StackFit.passthrough,
                            children: <Widget>[
                              Thumbnail(
                                index: index,
                                row: photos![index],
                                isSelected: _selectionController.isItemSelected(index),
                                controller: scrollToVisibleController,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
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

  final _MyHomePageState state;

  @override
  bool updateShouldNotify(covariant _HomeScope oldWidget) => false;
}

class ScrollToVisibleController {
  final Set<ScrollToVisibleListener> _listeners = <ScrollToVisibleListener>{};

  void addListener(ScrollToVisibleListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ScrollToVisibleListener listener) {
    _listeners.remove(listener);
  }

  void notifyListener(int index, ScrollPositionAlignmentPolicy policy) {
    for (ScrollToVisibleListener listener in _listeners) {
      if (listener.widget.index == index) {
        listener.handleScrollToVisible(policy);
      }
    }
  }
}

mixin ScrollToVisibleListener on State<Thumbnail> {
  void handleScrollToVisible(ScrollPositionAlignmentPolicy policy) {
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      Scrollable.ensureVisible(context, alignmentPolicy: policy);
    }, debugLabel: 'scrollToVisible');
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(this);
  }

  @override
  void dispose() {
    widget.controller.removeListener(this);
    super.dispose();
  }
}

class Thumbnail extends StatefulWidget {
  Thumbnail({
    required this.index,
    required this.row,
    required this.isSelected,
    required this.controller,
  }) : super(key: ValueKey<String>(row.path));

  final int index;
  final DbRow row;
  final bool isSelected;
  final ScrollToVisibleController controller;

  String get path => row.path;
  bool get hasLatlng => row.hasLatlng;

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> with ScrollToVisibleListener {
  void _handleRowUpdated(DbRow row) {
    assert(row == widget.row);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    DatabaseBinding.instance.setFileListener(widget.path, _handleRowUpdated);
  }

  @override
  void didUpdateWidget(covariant Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      DatabaseBinding.instance.setFileListener(oldWidget.path, null);
      DatabaseBinding.instance.setFileListener(widget.path, _handleRowUpdated);
    }
  }

  @override
  void dispose() {
    DatabaseBinding.instance.setFileListener(widget.path, null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Image.memory(
          widget.row.thumbnail,
          fit: BoxFit.cover,
          key: widget.key,
        ),
        Align(
          alignment: const Alignment(-1.0, 0.4),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(0xdd),
                backgroundBlendMode: BlendMode.srcATop,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  widget.row.hasDateTime ? Icons.date_range : Icons.date_range,
                  color: widget.row.hasDateTime ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(0xdd),
                backgroundBlendMode: BlendMode.srcATop,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  widget.hasLatlng ? Icons.location_on : Icons.location_off,
                  color: widget.hasLatlng ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
        ),
        if (widget.row.isModified)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(0xdd),
                  backgroundBlendMode: BlendMode.srcATop,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.save,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        if (widget.row.type == MediaType.video)
          const VideoPlaySymbol(),
        if (widget.isSelected)
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(width: 10, color: Colors.white)),
            child: const ColoredBox(color: Color(0x440000ff)),
          ),
      ],
    );
  }
}

class MainArea extends StatelessWidget {
  const MainArea({
    super.key,
    required this.row,
    required this.playPauseController,
  });

  final DbRow? row;
  final VideoPlayerPlayPauseController playPauseController;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: MainImage(
            row: row,
            playPauseController: playPauseController,
          ),
        ),
        SizedBox(
          width: 500,
          child: MetadataPanel(row),
        ),
      ],
    );
  }
}

class MainImage extends StatelessWidget {
  const MainImage({
    super.key,
    required this.row,
    required this.playPauseController,
    this.fs = const LocalFileSystem(),
  });

  final DbRow? row;
  final VideoPlayerPlayPauseController playPauseController;
  final FileSystem fs;

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return Container();
    }

    Widget result;
    switch (row!.type) {
      case MediaType.photo:
        result = Image.file(fs.file(row!.photoPath));
      case MediaType.video:
        return VideoPlayer(
          row: row!,
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
  const MetadataPanel(this.row, {super.key});

  final DbRow? row;

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
    if (widget.row == null) {
      latlngController.text = '';
    } else {
      String? currentUrl = await webViewController.currentUrl();
      if (widget.row!.hasLatlng) {
        final GpsCoordinates coords = widget.row!.coords!;
        latlngController.text = '${coords.latitude}, ${coords.longitude}';
        if (firstRun || currentUrl == null) {
          webViewController.loadRequest(Uri.parse('https://tvolkert.dev/map.html?initial=${coords.latitude},${coords.longitude}'));
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
    DateTime? newDateTime = await DateTimeEditorDialog.show(context, widget.row!.dateTime);
    if (newDateTime != null) {
      widget.row!
          ..dateTimeOriginal = newDateTime
          ..dateTimeDigitized = newDateTime
          ..isModified = true
          ..lastModified = DateTime.now()
          ;
      await widget.row!.commit();
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
      widget.row!
          ..latlng = coords.latlng
          ..isModified = true
          ..lastModified = DateTime.now()
          ;
      await widget.row!.commit();
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
    if (widget.row == null) {
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
                  Text(DateFormat('MMM d, yyyy').format(widget.row!.dateTime ?? DateTime.now())),
                  Text(DateFormat('E, h:mm a').format(widget.row!.dateTime ?? DateTime.now())),
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
              SelectableText(widget.row!.path.split('/').last),
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
