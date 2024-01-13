import 'package:chicago/chicago.dart' show isPlatformCommandKeyPressed, isShiftKeyPressed, ListViewSelectionController, SelectMode, Span;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../model/media.dart';
import '../model/tasks.dart';
import 'confirm_delete_files.dart';
import 'video_player.dart';

class ThumbnailList extends StatefulWidget {
  const ThumbnailList({super.key});

  @override
  State<ThumbnailList> createState() => _ThumbnailListState();
}

class _ThumbnailListState extends State<ThumbnailList> {
  late final ScrollController _scrollController;
  late final ListViewSelectionController _selectionController;
  late final FocusNode _focusNode;
  final _ScrollToVisibleController _scrollToVisibleController = _ScrollToVisibleController();
  int? _selectedItemId;

  static const double itemExtent = 175;

  MediaItems get items => MediaBinding.instance.items;

  void _handleItemCollectionChanged() {
    setState(() {
      // In addition to updating the selection, [build] references [items].
      // Hence, the unconditional [setState] call.
      if (_selectedItemId != null) {
        final int oldSelectedIndex = selectedIndex!;
        final int newSelectedIndex = items.indexOfId(_selectedItemId!);
        _selectionController.selectedIndex = newSelectedIndex;
        SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
          final double leftScrollOffset = newSelectedIndex * itemExtent;
          _scrollController.jumpTo(newSelectedIndex > oldSelectedIndex ? leftScrollOffset - context.size!.width + itemExtent : leftScrollOffset);
        });
      }
    });
  }

  void _handleSelectionChanged() {
    _selectedItemId = selectedIndex == null ? null : items[selectedIndex!].id;
    GeotagHome.of(context).setSelectedItems(_selectionController.selectedItems);
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    if (_selectionController.selectedItems.isNotEmpty && event is! KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
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
            _scrollToVisibleController.notifyListener(
              newSelectedIndex,
              ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            );
          });
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final int newSelectedIndex = _selectionController.lastSelectedIndex + 1;
        if (newSelectedIndex < items.length) {
          setState(() {
            _selectionController.selectedIndex = newSelectedIndex;
            _scrollToVisibleController.notifyListener(
              newSelectedIndex,
              ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          });
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        switch (items.comparator) {
          case ById():
            items.comparator = const ByDate(Ascending());
          case ByDate(direction: SortDirection direction):
            items.comparator = ByDate(direction.reversed);
        }
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
        switch (items.comparator) {
          case ById(direction: SortDirection direction):
            items.comparator = ById(direction.reversed);
          case ByDate():
            items.comparator = const ById(Ascending());
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

  Future<void> _deleteItems(Iterable<int> indexes) async {
    assert(indexes.length <= items.length);
    assert(indexes.every((int index) => index < items.length));
    TaskBinding.instance.addTasks(indexes.length);
    setState(() {
      final newNextIndex = _selectionController.lastSelectedIndex + 1 - indexes.length;
      if (newNextIndex < items.length - indexes.length) {
        _selectionController.selectedIndex = newNextIndex;
      } else if (_selectionController.firstSelectedIndex > 0) {
        _selectionController.selectedIndex = _selectionController.firstSelectedIndex - 1;
      } else {
        _selectionController.clearSelection();
        _focusNode.unfocus();
      }
    });
    await for (MediaItem _ in items.deleteFiles(indexes)) {
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
    MediaBinding.instance.addCollectionListener(_handleItemCollectionChanged);
  }

  @override
  void dispose() {
    MediaBinding.instance.removeCollectionListener(_handleItemCollectionChanged);
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
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.all(5),
                child: GestureDetector(
                  onTap: () => _handleTap(index),
                  child: _Thumbnail(
                    index: index,
                    item: items[index],
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
    required this.item,
    required this.isSelected,
    required this.controller,
  }) : super(key: ValueKey<String>(item.path));

  final int index;
  final MediaItem item;
  final bool isSelected;
  final _ScrollToVisibleController controller;

  String get path => item.path;
  bool get hasLatlng => item.hasLatlng;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> with _ScrollToVisibleListener {
  void _handleItemUpdated() {
    setState(() {
      // [build] references properties of [widget.item].
    });
  }

  @override
  void initState() {
    super.initState();
    MediaBinding.instance.addItemListener(widget.path, _handleItemUpdated);
  }

  @override
  void didUpdateWidget(covariant _Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      MediaBinding.instance.removeItemListener(oldWidget.path, _handleItemUpdated);
      MediaBinding.instance.addItemListener(widget.path, _handleItemUpdated);
    }
  }

  @override
  void dispose() {
    MediaBinding.instance.removeItemListener(widget.path, _handleItemUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Image.memory(
          widget.item.thumbnail,
          fit: BoxFit.cover,
          key: widget.key,
        ),
        _PropertyIndicator(
          alignment: const Alignment(-1.0, 0.4),
          icon: widget.item.hasDateTime ? Icons.date_range : Icons.date_range,
          color: widget.item.hasDateTime ? Colors.green : Colors.red,
        ),
        _PropertyIndicator(
          alignment: Alignment.bottomLeft,
          icon: widget.hasLatlng ? Icons.location_on : Icons.location_off,
          color: widget.hasLatlng ? Colors.green : Colors.red,
        ),
        if (widget.item.isModified)
          const _PropertyIndicator(
            alignment: Alignment.topRight,
            icon: Icons.save,
            color: Colors.red,
          ),
        if (widget.item.type == MediaType.video)
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
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
