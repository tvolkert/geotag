// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:chicago/chicago.dart'
    show
        isPlatformCommandKeyPressed,
        isShiftKeyPressed,
        ListViewSelectionController,
        SelectMode,
        Span;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bindings/media.dart';
import '../bindings/tasks.dart';
import '../extensions/iterable.dart';
import '../extensions/stream.dart';
import '../foundation/base.dart';
import '../foundation/reentrant_detector.dart';
import '../model/media.dart';
import 'dialogs.dart';
import 'home.dart';
import 'video_player.dart';

class ThumbnailList extends StatefulWidget {
  const ThumbnailList({super.key});

  @override
  State<ThumbnailList> createState() => _ThumbnailListState();
}

class _ThumbnailListState extends State<ThumbnailList> {
  late MediaItems _items;
  late final ScrollController _scrollController;
  late final ListViewSelectionController _selectionController;
  late final FocusNode _focusNode;
  final ReentrantDetector _jumpToScrollCheck = ReentrantDetector();
  late IndexedMediaItemFilter _selectionFilter;
  bool _showOnlyMissingDate = false;
  bool _showOnlyMissingGeotag = false;
  bool _showOnlyMissingEvent = false;

  static const double itemExtent = 175;
  static const MediaItemFilter _filterByDate = PredicateMediaItemFilter(_itemIsMissingDate);
  static const MediaItemFilter _filterByGeotag = PredicateMediaItemFilter(_itemIsMissingGeotag);
  static const MediaItemFilter _filterByEvent = PredicateMediaItemFilter(_itemIsMissingEvent);

  static bool _itemIsMissingDate(MediaItem item) => !item.hasDateTime;

  static bool _itemIsMissingGeotag(MediaItem item) => !item.hasLatlng;

  static bool _itemIsMissingEvent(MediaItem item) => !item.hasEvent;

  double? _calculateScrollToVisibleOffset(int index) {
    final double maxScrollOffset = math.max(0, _items.length * itemExtent - context.size!.width);
    const double minScrollOffset = 0;
    double leftScrollOffset = index * itemExtent;
    double rightScrollOffset = leftScrollOffset - context.size!.width + itemExtent;
    leftScrollOffset = math.min(leftScrollOffset, maxScrollOffset);
    rightScrollOffset = math.max(rightScrollOffset, minScrollOffset);
    if (_scrollController.offset < rightScrollOffset) {
      return rightScrollOffset;
    } else if (_scrollController.offset > leftScrollOffset) {
      return leftScrollOffset;
    } else {
      // Already visible
      return null;
    }
  }

  void _scrollToVisible(int index) {
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      final double? offset = _calculateScrollToVisibleOffset(index);
      if (offset != null) {
        _scrollController.jumpTo(offset);
      }
    });
  }

  void _updateItems() {
    MediaItems items = MediaBinding.instance.items;
    if (_showOnlyMissingDate) {
      items = items.where(_filterByDate);
    }
    if (_showOnlyMissingGeotag) {
      items = items.where(_filterByGeotag);
    }
    if (_showOnlyMissingEvent) {
      items = items.where(_filterByEvent);
    }

    List<int> newSelectedItems = <int>[];
    for (int i in _selectionController.selectedItems) {
      final int newIndex = items.indexOf(_items[i]);
      if (newIndex >= 0) {
        // The item only stays selected if it's in the new items view.
        newSelectedItems.add(newIndex);
      }
    }

    // It's important that we update the selection *after* [_items] since
    // [_handleSelectionChanged] resolves the selection against the items.
    setState(() {
      _items = items;
      _selectionController.selectedRanges = newSelectedItems.toRanges();
    });
  }

  void _updateSelectedItems() {
    _selectionFilter.removeListener(_handleFilteredIndexesChanged);
    _selectionFilter = IndexedMediaItemFilter(_selectionController.selectedItems);
    _selectionFilter.addListener(_handleFilteredIndexesChanged);
    final MediaItems selectedItems = _items.where(_selectionFilter);
    GeotagHome.of(context).featuredItems = selectedItems;
  }

  void _handleFilteredIndexesChanged() {
    setState(() {
      _selectionController.removeListener(_updateSelectedItems);
      try {
        _selectionController.clearSelection();
        double fromCurrent(double offset) => (offset - _scrollController.offset).abs();
        double scrollToVisibleOffset = double.infinity;
        bool isScrollNeeded = _selectionFilter.indexes.isNotEmpty;
        for (int index in _selectionFilter.indexes) {
          _selectionController.addSelectedIndex(index);
          if (isScrollNeeded) {
            final double? neededOffset = _calculateScrollToVisibleOffset(index);
            if (neededOffset == null) {
              isScrollNeeded = false;
            } else if (fromCurrent(neededOffset) < fromCurrent(scrollToVisibleOffset)) {
              scrollToVisibleOffset = neededOffset;
            }
          }
        }
        if (isScrollNeeded) {
          assert(scrollToVisibleOffset.isFinite);
          _scrollController.jumpTo(scrollToVisibleOffset);
        }
      } finally {
        _selectionController.addListener(_updateSelectedItems);
      }

      // Now that we're done mucking with the selection, we can update the
      // selected items. Doing so in the for loop above would have yielded
      // unnecessary churn.
      _updateSelectedItems();
    });
  }

  void _handleFilterByDate() {
    setState(() {
      _showOnlyMissingDate = !_showOnlyMissingDate;
      _updateItems();
    });
  }

  void _handleFilterByGeotag() {
    setState(() {
      _showOnlyMissingGeotag = !_showOnlyMissingGeotag;
      _updateItems();
    });
  }

  void _handleFilterByEvent() {
    setState(() {
      _showOnlyMissingEvent = !_showOnlyMissingEvent;
      _updateItems();
    });
  }

  void _handleSortByDate() {
    switch (_items.comparator) {
      case ById():
        _items.comparator = const ByDate(Ascending());
      case ByDate(direction: SortDirection direction):
        _items.comparator = ByDate(direction.reversed);
    }
  }

  void _handleSortById() {
    switch (_items.comparator) {
      case ById(direction: SortDirection direction):
        _items.comparator = ById(direction.reversed);
      case ByDate():
        _items.comparator = const ById(Ascending());
    }
  }

  void _handleDeleteSelectedItems() async {
    if (await ConfirmationDialog.confirmDeleteFiles(context)) {
      _deleteItems(_selectionController.selectedItems.toList());
    }
  }

  void _handleMoveSelectionLeft() {
    final int newSelectedIndex = _selectionController.firstSelectedIndex - 1;
    if (newSelectedIndex >= 0) {
      setState(() {
        if (isShiftKeyPressed()) {
          _selectionController.addSelectedIndex(newSelectedIndex);
        } else {
          _selectionController.selectedIndex = newSelectedIndex;
        }
        _scrollToVisible(newSelectedIndex);
      });
    }
  }

  void _handleMoveSelectionRight() {
    final int newSelectedIndex = _selectionController.lastSelectedIndex + 1;
    if (newSelectedIndex < _items.length) {
      setState(() {
        if (isShiftKeyPressed()) {
          _selectionController.addSelectedIndex(newSelectedIndex);
        } else {
          _selectionController.selectedIndex = newSelectedIndex;
        }
        _scrollToVisible(newSelectedIndex);
      });
    }
  }

  void _handleSelectAll() {
    if (_items.isNotEmpty) {
      setState(() {
        _selectionController.selectedRange = Span(0, _items.length - 1);
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode focusNode, KeyEvent event) {
    KeyEventResult result = KeyEventResult.ignored;
    if (_selectionController.selectedItems.isNotEmpty && event is! KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _handleDeleteSelectedItems();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _handleMoveSelectionLeft();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _handleMoveSelectionRight();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        _handleSortByDate();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyI) {
        _handleSortById();
        result = KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA && isPlatformCommandKeyPressed()) {
        _handleSelectAll();
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
    assert(indexes.length <= _items.length);
    assert(indexes.every((int index) => index < _items.length));
    TaskBinding.instance.addTasks(indexes.length);
    setState(() {
      final newNextIndex = _selectionController.lastSelectedIndex + 1;
      if (newNextIndex < _items.length) {
        _selectionController.selectedIndex = newNextIndex;
      } else if (_selectionController.firstSelectedIndex > 0) {
        _selectionController.selectedIndex = _selectionController.firstSelectedIndex - 1;
      } else {
        _selectionController.clearSelection();
        _focusNode.unfocus();
      }
    });
    await _jumpToScrollCheck.runAsyncCallback(() async {
      final MediaItems filtered = _items.where(IndexedMediaItemFilter(indexes));
      await filtered.deleteFiles().listenAndWait((void _) {
        TaskBinding.instance.onTaskCompleted();
        setState(() {});
      }, onError: (Object error, StackTrace stack) {
        print('$error\n$stack');
        TaskBinding.instance.onTaskCompleted();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectionController = ListViewSelectionController(selectMode: SelectMode.multi);
    _selectionController.addListener(_updateSelectedItems);
    MediaBinding.instance.items.addStructureListener(_updateItems);
    _focusNode = FocusNode();
    _updateItems();
    _selectionFilter = IndexedMediaItemFilter(_selectionController.selectedItems);
    _selectionFilter.addListener(_handleFilteredIndexesChanged);
  }

  @override
  void dispose() {
    _selectionFilter.removeListener(_handleFilteredIndexesChanged);
    _selectionFilter.dispose();
    _focusNode.dispose();
    MediaBinding.instance.items.removeStructureListener(_updateItems);
    _selectionController.removeListener(_updateSelectedItems);
    _selectionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: _ButtonBar(
                    buttons: <_ToggleButton>[
                      _ToggleButton(
                        icon: Icons.calendar_today,
                        tooltipMessage: 'Show only missing date',
                        isSelected: () => _showOnlyMissingDate,
                        onPressed: _handleFilterByDate,
                      ),
                      _ToggleButton(
                        icon: Icons.location_off,
                        tooltipMessage: 'Show only missing geotag',
                        isSelected: () => _showOnlyMissingGeotag,
                        onPressed: _handleFilterByGeotag,
                      ),
                      _ToggleButton(
                        icon: Icons.local_activity,
                        tooltipMessage: 'Show only missing event',
                        isSelected: () => _showOnlyMissingEvent,
                        onPressed: _handleFilterByEvent,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _ButtonBar(
                    alignment: MainAxisAlignment.end,
                    buttons: <_ToggleButton>[
                      _ToggleButton(
                        icon: Icons.calendar_today,
                        tooltipMessage: 'Sort by date',
                        isSelected: () => _items.comparator is ByDate,
                        onPressed: _handleSortByDate,
                      ),
                      _ToggleButton(
                        icon: Icons.onetwothree,
                        tooltipMessage: 'Sort by ID',
                        isSelected: () => _items.comparator is ById,
                        onPressed: _handleSortById,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: itemExtent,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 12,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKeyEvent,
                child: ListView.builder(
                  itemExtent: itemExtent,
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(5),
                      child: GestureDetector(
                        onTap: () => _handleTap(index),
                        child: Thumbnail(
                          index: index,
                          item: _items[index],
                          isSelected: _selectionController.isItemSelected(index),
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
    );
  }
}

class _ButtonBar extends StatelessWidget {
  const _ButtonBar({
    required this.buttons,
    this.alignment = MainAxisAlignment.start,
  });

  final List<_ToggleButton> buttons;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: alignment,
      children: <Widget>[
        ToggleButtons(
          borderColor: const Color(0xff777777),
          selectedBorderColor: const Color(0xff777777),
          color: const Color(0xff777777),
          selectedColor: const Color(0xfff4f4f4),
          isSelected: buttons.map<bool>((_ToggleButton button) => button.isSelected()).toList(),
          onPressed: (int index) => buttons[index].onPressed(),
          children: buttons,
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltipMessage,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltipMessage;
  final EmptyPredicate isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltipMessage,
      child: Icon(icon),
    );
  }
}

class Thumbnail extends StatefulWidget {
  Thumbnail({
    required this.index,
    required this.item,
    required this.isSelected,
  }) : super(key: ValueKey<String>(item.path));

  final int index;
  final MediaItem item;
  final bool isSelected;

  int get id => item.id;
  bool get hasLatlng => item.hasLatlng;

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  void _handleItemUpdated() {
    setState(() {
      // [build] references properties of [widget.item].
    });
  }

  @override
  void initState() {
    super.initState();
    MediaBinding.instance.items.addMetadataListener(_handleItemUpdated, id: widget.id);
  }

  @override
  void didUpdateWidget(covariant Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      MediaBinding.instance.items.removeMetadataListener(_handleItemUpdated, id: oldWidget.id);
      MediaBinding.instance.items.addMetadataListener(_handleItemUpdated, id: widget.id);
    }
  }

  @override
  void dispose() {
    MediaBinding.instance.items.removeMetadataListener(_handleItemUpdated, id: widget.id);
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
