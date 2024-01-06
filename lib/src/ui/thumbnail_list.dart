import 'package:chicago/chicago.dart' show isPlatformCommandKeyPressed, isShiftKeyPressed, ListViewSelectionController, SelectMode, Span;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../model/db.dart';
import '../model/tasks.dart';
import 'confirm_delete_files.dart';
import 'video_player.dart';

class ThumbnailList extends StatefulWidget {
  const ThumbnailList({super.key, required this.photos});

  final DbResults? photos;

  @override
  State<ThumbnailList> createState() => _ThumbnailListState();
}

class _ThumbnailListState extends State<ThumbnailList> {
  late final ScrollController _scrollController;
  late final ListViewSelectionController _selectionController;
  late final FocusNode _focusNode;
  final _ScrollToVisibleController _scrollToVisibleController = _ScrollToVisibleController();

  static const double itemExtent = 175;

  void _handleSelectionChanged() {
    MyHomePage.of(context).setSelectedItems(_selectionController.selectedItems);
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    if (widget.photos != null && _selectionController.selectedItems.isNotEmpty && event is! KeyUpEvent) {
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
            _scrollToVisibleController.notifyListener(newSelectedIndex, ScrollPositionAlignmentPolicy.keepVisibleAtStart);
          });
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final int newSelectedIndex = _selectionController.lastSelectedIndex + 1;
        if (newSelectedIndex < widget.photos!.length) {
          setState(() {
            _selectionController.selectedIndex = newSelectedIndex;
            _scrollToVisibleController.notifyListener(newSelectedIndex, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
          });
        }
        result = KeyEventResult.handled;
      }
    }
    return result;
  }

  void _handleTap(int index) {
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
  }

  int? get selectedIndex => _selectionController.selectedItems.singleOrNull;

  DbRow? get selectedRow => selectedIndex == null ? null : widget.photos?[selectedIndex!];

  Future<void> _deleteItems(Iterable<int> indexes) async {
    assert(widget.photos != null);
    assert(indexes.length <= widget.photos!.length);
    assert(indexes.every((int index) => index < widget.photos!.length));
    TaskBinding.instance.addTasks(indexes.length);
    setState(() {
      final newNextIndex = _selectionController.lastSelectedIndex + 1 - indexes.length;
      if (newNextIndex < widget.photos!.length - indexes.length) {
        _selectionController.selectedIndex = newNextIndex;
      } else if (_selectionController.firstSelectedIndex > 0) {
        _selectionController.selectedIndex = _selectionController.firstSelectedIndex - 1;
      } else {
        _selectionController.clearSelection();
        _focusNode.unfocus();
      }
    });
    await for (DbRow _ in widget.photos!.deleteFiles(indexes)) {
      TaskBinding.instance.onTaskCompleted();
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectionController = ListViewSelectionController(selectMode: SelectMode.multi);
    _selectionController.addListener(_handleSelectionChanged);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _selectionController.removeListener(_handleSelectionChanged);
    _selectionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemExtent,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: ListView.builder(
            itemExtent: itemExtent,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.photos?.length ?? 0,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.all(5),
                child: GestureDetector(
                  onTap: () => _handleTap(index),
                  child: _Thumbnail(
                    index: index,
                    row: widget.photos![index],
                    isSelected: _selectionController.isItemSelected(index),
                    controller: _scrollToVisibleController,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrollToVisibleController {
  final Set<_ScrollToVisibleListener> _listeners = <_ScrollToVisibleListener>{};

  void addListener(_ScrollToVisibleListener listener) {
    _listeners.add(listener);
  }

  void removeListener(_ScrollToVisibleListener listener) {
    _listeners.remove(listener);
  }

  void notifyListener(int index, ScrollPositionAlignmentPolicy policy) {
    for (_ScrollToVisibleListener listener in _listeners) {
      if (listener.widget.index == index) {
        listener.handleScrollToVisible(policy);
      }
    }
  }
}

mixin _ScrollToVisibleListener on State<_Thumbnail> {
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

class _Thumbnail extends StatefulWidget {
  _Thumbnail({
    required this.index,
    required this.row,
    required this.isSelected,
    required this.controller,
  }) : super(key: ValueKey<String>(row.path));

  final int index;
  final DbRow row;
  final bool isSelected;
  final _ScrollToVisibleController controller;

  String get path => row.path;
  bool get hasLatlng => row.hasLatlng;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> with _ScrollToVisibleListener {
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
  void didUpdateWidget(covariant _Thumbnail oldWidget) {
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
        _PropertyIndicator(
          alignment: const Alignment(-1.0, 0.4),
          icon: widget.row.hasDateTime ? Icons.date_range : Icons.date_range,
          color: widget.row.hasDateTime ? Colors.green : Colors.red,
        ),
        _PropertyIndicator(
          alignment: Alignment.bottomLeft,
          icon: widget.hasLatlng ? Icons.location_on : Icons.location_off,
          color: widget.hasLatlng ? Colors.green : Colors.red,
        ),
        if (widget.row.isModified)
          const _PropertyIndicator(
            alignment: Alignment.topRight,
            icon: Icons.save,
            color: Colors.red,
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

class _PropertyIndicator extends StatelessWidget {
  const _PropertyIndicator({
    required this.alignment,
    required this.icon,
    required this.color,
  });

  final AlignmentGeometry alignment;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
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
              icon,
              color: Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
