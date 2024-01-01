// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:chicago/chicago.dart' show isPlatformCommandKeyPressed, isShiftKeyPressed, ListViewSelectionController, SelectMode, Span;
import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/extensions/duration.dart';
import 'src/model/app.dart';
import 'src/model/db.dart';
import 'src/model/gps.dart';

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
        primarySwatch: Colors.indigo,
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

class VideoPlayerPlayPauseController {
  VoidCallback? _onPlayPause;
  set onPlayPause(VoidCallback? listener) {
    _onPlayPause = listener;
  }

  void playPause() {
    _onPlayPause?.call();
  }
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
          final bool? confirmed = await showModalBottomSheet<bool>(
            context: context,
            builder: (BuildContext context) => const ConfirmDeleteFilesDialog(),
          );
          if (confirmed ?? false) {
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
      _selectionController.clearSelection();
      _focusNode.unfocus();
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

class ConfirmDeleteFilesDialog extends StatelessWidget {
  const ConfirmDeleteFilesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 151, 200, 223),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        )
      ),
      child: SizedBox(
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            const Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  'Are you sure you wan to delete the selected files?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop<bool>(context, false),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(),
                    ),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        child: const Text('Yes'),
                        onPressed: () => Navigator.pop<bool>(context, true),
                      ),
                    ),
                  ],
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
          const VideoPlayButton(),
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
          child: GeoSetter(row),
        ),
      ],
    );
  }
}

class MainImage extends StatefulWidget {
  const MainImage({
    super.key,
    required this.row,
    required this.playPauseController,
  });

  final DbRow? row;
  final VideoPlayerPlayPauseController playPauseController;

  @override
  State<MainImage> createState() => _MainImageState();
}

class _MainImageState extends State<MainImage> {
  VideoPlayerController? _videoController;
  bool _hasPlayedOnce = false; // https://github.com/flutter/flutter/issues/140782

  void _handlePlayPauseVideo() {
    assert(_videoController != null);
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _hasPlayedOnce = true;
        _videoController!.play();
      }
    });
  }

  void _initializeVideoController() {
    if (widget.row != null) {
      const LocalFileSystem fs = LocalFileSystem();
      _videoController = VideoPlayerController.file(fs.file(widget.row!.path));
      _videoController!.setLooping(true);
      _videoController!.initialize().then((void _) {
        setState(() {});
      });
      _hasPlayedOnce = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
    widget.playPauseController.onPlayPause = _handlePlayPauseVideo;
  }

  @override
  void didUpdateWidget(covariant MainImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row?.path != oldWidget.row?.path) {
      if (_videoController?.value.isPlaying ?? false) {
        _videoController!.pause();
      }
      _videoController?.pause();
      // TODO: Can we just update it instead of disposing and re-creating?
      _videoController?.dispose();
      _videoController = null;
      _initializeVideoController();
    }
  }

  @override
  void dispose() {
    widget.playPauseController.onPlayPause = null;
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.row == null) {
      return Container();
    }

    final Widget photoImage = Image.file(const LocalFileSystem().file(widget.row!.photoPath));
    switch (widget.row!.type) {
      case MediaType.photo:
        return photoImage;
      case MediaType.video:
        assert(_videoController != null);
        final Widget videoPlayer = Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        );
        if (!_videoController!.value.isInitialized) {
          return photoImage;
        } else if (_videoController!.value.isPlaying) {
          return Stack(
            fit: StackFit.passthrough,
            children: [
              GestureDetector(
                onTap: _handlePlayPauseVideo,
                child: videoPlayer,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _VideoProgressMonitor(
                  controller: _videoController!,
                ),
              ),
            ],
          );
        } else {
          return Stack(
            fit: StackFit.passthrough,
            children: [
              _hasPlayedOnce ? videoPlayer : photoImage,
              GestureDetector(
                onTap: _handlePlayPauseVideo,
                child: const VideoPlayButton(),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _VideoProgressMonitor(
                  controller: _videoController!,
                ),
              ),
            ],
          );
        }
    }
  }
}

class _VideoProgressMonitor extends StatefulWidget {
  const _VideoProgressMonitor({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoProgressMonitor> createState() => _VideoProgressMonitorState();
}

class _VideoProgressMonitorState extends State<_VideoProgressMonitor> {
  double _progress = 0;
  String _positionText = '';
  String _durationText = '';
  bool _pointerDown = false;

  void _handleProgressUpdate() {
    setState(() {
      final VideoPlayerValue value = widget.controller.value;
      _progress = value.position.inMilliseconds / value.duration.inMilliseconds;
      _positionText = value.position.toSecondsPrecision();
      _durationText = value.duration.toSecondsPrecision();
    });
  }

  void _seekToEventPosition(PointerEvent event) {
    final Duration total = widget.controller.value.duration;
    final double percentage = event.localPosition.dx / context.size!.width;
    final Duration seekTo = total * percentage;
    widget.controller.seekTo(seekTo);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _seekToEventPosition(event);
    setState(() {
      _pointerDown = true;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    setState(() {
      _pointerDown = false;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    assert(_pointerDown);
    _seekToEventPosition(event);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleProgressUpdate);
    _handleProgressUpdate();
  }

  @override
  void didUpdateWidget(covariant _VideoProgressMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleProgressUpdate);
      widget.controller.addListener(_handleProgressUpdate);
      _handleProgressUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleProgressUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 21,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerUp,
              onPointerMove: _pointerDown ? _handlePointerMove : null,
              child: AbsorbPointer(
                child: Align(
                  alignment: const Alignment(-1, 0),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: _progress,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 3),
          child: Row(
            children: <Widget>[
              ConstrainedBox(constraints: const BoxConstraints(minWidth: 45), child: Text(_positionText)),
              ConstrainedBox(constraints: const BoxConstraints(minWidth: 10), child: const Text('/')),
              ConstrainedBox(constraints: const BoxConstraints(minWidth: 45), child: Text(_durationText)),
            ],
          ),
        ),
      ],
    );
  }
}

class VideoPlayButton extends StatelessWidget {
  const VideoPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double size = (constraints.biggest / 5).shortestSide;
          return SizedBox(
            width: size,
            height: size,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xaa000000),
                borderRadius: BorderRadius.all(Radius.circular(10))
              ),
              child: CustomPaint(painter: PlayButtonPainter()),
            ),
          );
        }
      ),
    );
  }
}

class PlayButtonPainter extends CustomPainter {
  const PlayButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    ui.Paint paint = ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = Colors.white
        ;
    ui.Path path = ui.Path()
        ..moveTo(size.width / 3, size.height / 3)
        ..lineTo(size.width * 2 / 3, size.height / 2)
        ..lineTo(size.width / 3, size.height * 2 / 3)
        ..close()
        ;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class GeoSetter extends StatefulWidget {
  const GeoSetter(this.row, {super.key});

  final DbRow? row;

  @override
  State<GeoSetter> createState() => _GeoSetterState();
}

class _GeoSetterState extends State<GeoSetter> {
  bool _isEditingDateTime = false;
  bool _isEditingLatlng = false;
  late TextEditingController dateTimeController;
  late TextEditingController latlngController;
  late FocusNode dateTimeFocusNode;
  late FocusNode latlngFocusNode;
  late final WebViewController webViewController;

  Future<void> _updateRow({bool firstRun = false}) async {
    if (widget.row == null) {
      latlngController.text = '';
      dateTimeController.text = '';
    } else {
      if (widget.row!.hasDateTime) {
        dateTimeController.text = widget.row!.dateTime!.toIso8601String();
      } else {
        dateTimeController.text = '';
      }
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

  void _handleDateTimeSubmitted(String value) {
    assert(value == dateTimeController.text);
    setIsEditingDateTime(false);
  }

  void _handleLatlngSubmitted(String value) {
    assert(value == latlngController.text);
    setIsEditingLatlng(false);
  }

  void _handleFocusChanged() {
    setIsEditingDateTime(FocusManager.instance.primaryFocus == dateTimeFocusNode);
    setIsEditingLatlng(FocusManager.instance.primaryFocus == latlngFocusNode);
  }

  void setIsEditingDateTime(bool value) {
    if (value != _isEditingDateTime) {
      _isEditingDateTime = value;
      if (!value) {
        _saveEdits();
      }
    }
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
      final DateTime? date = dateTimeController.text.isEmpty ? null : DateTime.parse(dateTimeController.text);
      widget.row!
          ..latlng = coords.latlng
          ..dateTimeOriginal = date
          ..dateTimeDigitized = date
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
    dateTimeController = TextEditingController();
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
  void didUpdateWidget(covariant GeoSetter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRow(firstRun: false);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    latlngFocusNode.dispose();
    dateTimeFocusNode.dispose();
    latlngController.dispose();
    dateTimeController.dispose();
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
        SelectableText(widget.row!.path),
        Center(
          child: TextField(
            controller: dateTimeController,
            focusNode: dateTimeFocusNode,
            onSubmitted: _handleDateTimeSubmitted,
          ),
        ),
        const Divider(),
        Center(
          child: TextField(
            controller: latlngController,
            focusNode: latlngFocusNode,
            onSubmitted: _handleLatlngSubmitted,
          ),
        ),
        const Divider(),
        const SizedBox(width: 1, height: 20),
        const Divider(),
        Expanded(
          child: WebViewWidget(controller: webViewController),
        ),
      ],
    );
  }
}
