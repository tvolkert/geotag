// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:ui' as ui;

import 'package:chicago/chicago.dart' show isPlatformCommandKeyPressed, isShiftKeyPressed, ListViewSelectionController, SelectMode, Span;
import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
                        autofocus: true,
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
          child: MetadataPanel(row),
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
    Widget result;
    switch (widget.row!.type) {
      case MediaType.photo:
        result = photoImage;
      case MediaType.video:
        assert(_videoController != null);
        if (!_videoController!.value.isInitialized) {
          result = photoImage;
        } else {
          result = Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: GestureDetector(
                onTap: _handlePlayPauseVideo,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _hasPlayedOnce ? VideoPlayer(_videoController!) : photoImage,
                    _VideoProgressMonitor(
                      controller: _videoController!,
                      forceIsVisible: !_videoController!.value.isPlaying,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    }
    return ColoredBox(
      color: Colors.black,
      child: result,
    );
  }
}

class _VideoProgressMonitor extends StatefulWidget {
  const _VideoProgressMonitor({
    required this.controller,
    required this.forceIsVisible,
  });

  final VideoPlayerController controller;
  final bool forceIsVisible;

  @override
  State<_VideoProgressMonitor> createState() => _VideoProgressMonitorState();
}

class _VideoProgressMonitorState extends State<_VideoProgressMonitor> {
  double _progress = 0;
  String _positionText = '';
  String _durationText = '';
  bool _isPlaying = false;
  bool _pointerDown = false;
  bool _isVisible = false;
  Timer? _hoverTimer;

  static const Duration _fadeDuration = Duration(milliseconds: 100);
  static const Duration _visibleDuration = Duration(seconds: 3);

  static const BoxDecoration _gradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[Color(0x99000000), Colors.transparent],
      begin: Alignment.bottomCenter,
      end: Alignment.center,
    ),
  );

  void _handleProgressUpdate() {
    setState(() {
      final VideoPlayerValue value = widget.controller.value;
      _progress = value.position.inMilliseconds / value.duration.inMilliseconds;
      _positionText = value.position.toSecondsPrecision();
      _durationText = value.duration.toSecondsPrecision();
      _isPlaying = value.isPlaying;
    });
  }

  void _handlePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _seekToEventPosition(PointerEvent event) {
    final Duration total = widget.controller.value.duration;
    final double percentage = event.localPosition.dx / context.size!.width;
    final Duration seekTo = total * percentage;
    widget.controller.seekTo(seekTo);
  }

  void _consumeTap() {
    // Consume the tap event so it doesn't play/pause the video
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

  void _handlePointerHover(PointerHoverEvent event) {
    setState(() {
      _isVisible = true;
    });
    _resetHoverTimer();
  }

  void _resetHoverTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(_visibleDuration, () {
      assert(mounted);
      setState(() {
        _isVisible = false;
        _hoverTimer = null;
      });
    });
  }

  bool get isVisible => widget.forceIsVisible || _isVisible;

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
    if (widget.forceIsVisible != oldWidget.forceIsVisible && oldWidget.forceIsVisible) {
      _isVisible = true;
      _resetHoverTimer();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    widget.controller.removeListener(_handleProgressUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: _handlePointerHover,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: _fadeDuration,
        child: DecoratedBox(
          decoration: _gradientDecoration,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 21,
                  child: GestureDetector(
                    onTap: _consumeTap,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 3),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _PlayPauseButton(isPlaying: _isPlaying, onPlayPause: _handlePlayPause),
                        const SizedBox(width: 10),
                        ConstrainedBox(constraints: const BoxConstraints(minWidth: 45), child: Text(_positionText)),
                        ConstrainedBox(constraints: const BoxConstraints(minWidth: 10), child: const Text('/')),
                        ConstrainedBox(constraints: const BoxConstraints(minWidth: 45), child: Text(_durationText)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends ImplicitlyAnimatedWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPlayPause,
  }) : super(duration: const Duration(milliseconds: 200));

  final bool isPlaying;
  final VoidCallback onPlayPause;

  @override
  AnimatedWidgetBaseState<_PlayPauseButton> createState() => _PlayPauseButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isPlaying', isPlaying));
  }
}

class _PlayPauseButtonState extends AnimatedWidgetBaseState<_PlayPauseButton> {
  Tween<double>? _value;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _value = visitor(
      _value,
      widget.isPlaying ? PlayPauseButtonPainter.pauseSymbol : PlayPauseButtonPainter.playSymbol,
      (dynamic value) => Tween<double>(begin: value as double)
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPlayPause,
        child: SizedBox(
          width: 40,
          height: 50,
          child: CustomPaint(
            painter: PlayPauseButtonPainter(value: _value!.evaluate(animation)),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<Tween<double>>('value', _value, defaultValue: null));
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
              child: CustomPaint(painter: PlayPauseButtonPainter(value: PlayPauseButtonPainter.playSymbol)),
            ),
          );
        }
      ),
    );
  }
}

class PlayPauseButtonPainter extends CustomPainter {
  const PlayPauseButtonPainter({
    required this.value,
  });

  final double value;

  static const double playSymbol = 0;
  static const double pauseSymbol = 1;

  @override
  void paint(Canvas canvas, Size size) {
    ui.Paint paint = ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = Colors.white
        ;
    List<Offset> pauseOffsets = <Offset>[
      Offset(size.width / 3, size.height / 3),
      Offset(size.width * 4 / 9, size.height / 3),
      Offset(size.width * 4 / 9, size.height * 2 / 3),
      Offset(size.width / 3, size.height * 2 / 3),
      Offset(size.width * 5 / 9, size.height / 3),
      Offset(size.width * 2 / 3, size.height / 3),
      Offset(size.width * 2 / 3, size.height * 2 / 3),
      Offset(size.width * 5 / 9, size.height * 2 / 3),
    ];
    List<Offset> playOffsets = <Offset>[
      Offset(size.width / 3, size.height / 3),
      Offset(size.width / 2, size.height * 5 / 12),
      Offset(size.width / 2, size.height * 7 / 12),
      Offset(size.width / 3, size.height * 2 / 3),
      Offset(size.width / 2, size.height * 5 / 12),
      Offset(size.width * 2 / 3, size.height / 2),
      Offset(size.width * 2 / 3, size.height / 2),
      Offset(size.width / 2, size.height * 7 / 12),
    ];

    List<Offset> offsets;
    if (value == playSymbol) {
      offsets = playOffsets;
    } else if (value == pauseSymbol) {
      offsets = pauseOffsets;
    } else {
      offsets = List<Offset>.generate(playOffsets.length, (int index) {
        return Offset.lerp(playOffsets[index], pauseOffsets[index], value)!;
      });
    }

    ui.Path path = ui.Path()
        ..moveTo(offsets[0].dx, offsets[0].dy)
        ..lineTo(offsets[1].dx, offsets[1].dy)
        ..lineTo(offsets[2].dx, offsets[2].dy)
        ..lineTo(offsets[3].dx, offsets[3].dy)
        ..close()
        ..moveTo(offsets[4].dx, offsets[4].dy)
        ..lineTo(offsets[5].dx, offsets[5].dy)
        ..lineTo(offsets[6].dx, offsets[6].dy)
        ..lineTo(offsets[7].dx, offsets[7].dy)
        ..close()
        ;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PlayPauseButtonPainter oldDelegate) {
    return value != oldDelegate.value;
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
    DateTime? newDateTime = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) => DateTimeEditorDialog(initialDateTime: widget.row!.dateTime),
    );
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

class DateTimeEditorDialog extends StatefulWidget {
  const DateTimeEditorDialog({
    super.key,
    required this.initialDateTime,
  });

  final DateTime? initialDateTime;

  @override
  State<DateTimeEditorDialog> createState() => _DateTimeEditorDialogState();
}

enum _AmPm {
  am,
  pm,
}

class _DateTimeEditorDialogState extends State<DateTimeEditorDialog> {
  late int year, defaultYear;
  late int month, defaultMonth;
  late int day, defaultDay;
  late int hour, defaultHour;
  late int minute, defaultMinute;
  late _AmPm ampm, defaultAmPm;

  void _handleYearChanged(int value) {
    setState(() {
      year = value;
    });
  }

  void _handleMonthChanged(int value) {
    setState(() {
      month = value;
    });
  }

  void _handleDayChanged(int value) {
    setState(() {
      day = value;
    });
  }

  void _handleHourChanged(int value) {
    setState(() {
      hour = value;
    });
  }

  void _handleMinuteChanged(int value) {
    setState(() {
      minute = value;
    });
  }

  void _handleAmPmChanged(_AmPm value) {
    setState(() {
      ampm = value;
    });
  }

  void _handleCancel() {
    Navigator.pop<DateTime>(context);
  }

  void _handleSave() {
    Navigator.pop<DateTime>(context, currentDateTime);
  }

  DateTime get currentDateTime {
    final int hour24 = hour + (ampm == _AmPm.pm ? 12 : 0);
    return DateTime(year, month, day, hour24, minute);
  }

  String _formatCurrentDateTime() {
    final DateFormat format = DateFormat('EEEE, MMMM d, yyyy, h:mm a');
    return format.format(currentDateTime);
  }

  _initialize() {
    final DateTime instant = widget.initialDateTime ?? DateTime.now();
    year = defaultYear = instant.year;
    month = defaultMonth = instant.month;
    day = defaultDay = instant.day;
    hour = defaultHour = instant.hour % 12;
    minute = defaultMinute = instant.minute;
    ampm = defaultAmPm = instant.hour < 12 ? _AmPm.am : _AmPm.pm;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant DateTimeEditorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateTime != oldWidget.initialDateTime) {
      _initialize();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        // backgroundColor: Colors.white,
        // surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Edit date & time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_formatCurrentDateTime()),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _IntEntry(defaultValue: defaultYear, label: 'Year', maxLength: 4, onValueChanged: _handleYearChanged, autofocus: true),
                  const SizedBox(width: 8),
                  _IntEntry(defaultValue: defaultMonth, label: 'Month', onValueChanged: _handleMonthChanged),
                  const SizedBox(width: 8),
                  _IntEntry(defaultValue: defaultDay, label: 'Day', onValueChanged: _handleDayChanged),
                  const SizedBox(width: 12),
                  _IntEntry(defaultValue: defaultHour, label: 'Time', onValueChanged: _handleHourChanged),
                  const SizedBox(width: 8, child: Center(child: Text(':'))),
                  _IntEntry(defaultValue: defaultMinute, onValueChanged: _handleMinuteChanged),
                  const SizedBox(width: 8),
                  _AmPmEntry(defaultValue: defaultAmPm, onValueChanged: _handleAmPmChanged),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  const SizedBox(width: 500),
                  _ActionButton(label: 'Cancel', onPressed: _handleCancel),
                  const SizedBox(width: 10),
                  _ActionButton(label: 'Save', onPressed: _handleSave),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntValidatingTextEditingController extends TextEditingController {
  _IntValidatingTextEditingController(this.onValueChanged);

  final ValueChanged<int> onValueChanged;
  bool _doingSetup = false;

  void invokeSetupCallback(VoidCallback callback) {
    _doingSetup = true;
    try {
      callback();
    } finally {
      _doingSetup = false;
    }
  }

  @override
  set value(TextEditingValue newValue) {
    final String newText = newValue.text;
    final bool textChanged = newText != value.text;
    final int? intValue = int.tryParse(newValue.text);
    if (newText.isEmpty || (intValue != null && intValue >= 0)) {
      super.value = newValue;
      if (!_doingSetup && textChanged && intValue != null) {
        onValueChanged(intValue);
      }
    }
  }
}

class _IntEntry extends StatefulWidget {
  const _IntEntry({
    required this.defaultValue,
    this.label = '',
    this.maxLength = 2,
    required this.onValueChanged,
    this.autofocus = false,
  });

  final int defaultValue;
  final String label;
  final int maxLength;
  final ValueChanged<int> onValueChanged;
  final bool autofocus;

  @override
  State<_IntEntry> createState() => _IntEntryState();
}

class _IntEntryState extends State<_IntEntry> {
  late final FocusNode _focusNode;
  late final _IntValidatingTextEditingController _controller;
  bool _hasFocus = false;

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      if (_hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      } else if (_controller.text.isEmpty) {
        _controller.text = '${widget.defaultValue}';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller = _IntValidatingTextEditingController(widget.onValueChanged);
    _controller.invokeSetupCallback(() {
      _controller.text = '${widget.defaultValue}';
    });
  }

  @override
  void didUpdateWidget(covariant _IntEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.onValueChanged == oldWidget.onValueChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Entry(
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      controller: _controller,
      onTap: null,
      maxLength: widget.maxLength,
      labelText: widget.label,
      hasFocus: _hasFocus,
    );
  }
}

class _AmPmValidatingTextEditingController extends TextEditingController {
  _AmPmValidatingTextEditingController(this.onValueChanged);

  final ValueChanged<_AmPm> onValueChanged;
  bool _doingSetup = false;

  static const TextSelection selectAll = TextSelection(baseOffset: 0, extentOffset: 2);

  void invokeSetupCallback(VoidCallback callback) {
    _doingSetup = true;
    try {
      callback();
    } finally {
      _doingSetup = false;
    }
  }

  @override
  set value(TextEditingValue newValue) {
    switch (newValue.text.toLowerCase()) {
      case 'a':
      case 'am':
        super.value = const TextEditingValue(text: 'AM', selection: selectAll);
        if (!_doingSetup) {
          onValueChanged(_AmPm.am);
        }
      case 'p':
      case 'pm':
        super.value = const TextEditingValue(text: 'PM', selection: selectAll);
        if (!_doingSetup) {
          onValueChanged(_AmPm.pm);
        }
    }
  }
}

class _AmPmEntry extends StatefulWidget {
  const _AmPmEntry({
    required this.defaultValue,
    required this.onValueChanged,
  });

  final _AmPm defaultValue;
  final ValueChanged<_AmPm> onValueChanged;

  @override
  State<_AmPmEntry> createState() => _AmPmEntryState();
}

class _AmPmEntryState extends State<_AmPmEntry> {
  late final FocusNode _focusNode;
  late final _AmPmValidatingTextEditingController _controller;
  bool _hasFocus = false;

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      if (_hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    }
  }

  void _handleTap() {
    switch (_controller.text) {
      case 'AM':
        _controller.text = 'PM';
      case 'PM':
        _controller.text = 'AM';
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller = _AmPmValidatingTextEditingController(widget.onValueChanged);
    _controller.invokeSetupCallback(() {
      _controller.text = widget.defaultValue == _AmPm.am ? 'AM' : 'PM';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Entry(
      autofocus: false,
      focusNode: _focusNode,
      controller: _controller,
      onTap: _handleTap,
      maxLength: 2,
      labelText: '',
      hasFocus: _hasFocus,
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.autofocus,
    required this.focusNode,
    required this.controller,
    required this.onTap,
    required this.maxLength,
    required this.labelText,
    required this.hasFocus,
  });

  final bool autofocus;
  final FocusNode focusNode;
  final TextEditingController controller;
  final GestureTapCallback? onTap;
  final int maxLength;
  final String labelText;
  final bool hasFocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: TextField(
        autofocus: autofocus,
        focusNode: focusNode,
        controller: controller,
        maxLength: maxLength,
        onTap: onTap,
        maxLines: 1,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(fontSize: 15),
          counterText: '',
          filled: true,
          fillColor: hasFocus ? const Color(0xffe7e9ea) : const Color(0xfff1f3f4),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: const Color.fromARGB(255, 56, 113, 224),
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(fontSize: 14),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
