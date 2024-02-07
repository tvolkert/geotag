import 'package:flutter/widgets.dart';

class SortIntent extends Intent {
  const SortIntent(this.key);

  final SortKey key;
}

enum SortKey {
  date,
  itemId,
  filename,
}
