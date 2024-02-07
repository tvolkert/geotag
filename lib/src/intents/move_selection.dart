import 'package:flutter/widgets.dart';

import '../model/media.dart';

class MoveSelectionIntent extends Intent {
  const MoveSelectionIntent.forward() : getNewSelectedIndex = _getForwardIndex;

  const MoveSelectionIntent.backward() : getNewSelectedIndex = _getBackwardIndex;

  final int Function(IndexedMediaItems items) getNewSelectedIndex;

  static int _getForwardIndex(IndexedMediaItems items) => items.lastIndex + 1;

  static int _getBackwardIndex(IndexedMediaItems items) => items.firstIndex - 1;
}
