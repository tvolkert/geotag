import 'package:chicago/chicago.dart' show Span;

extension IterableExtensions<T> on Iterable<T> {
  /// Whether this collection has one and only one element.
  bool get isSingle => length == 1;

  /// Creates a new lazy [Iterable] with any duplicate items removed.
  ///
  /// Duplicate items are determined by logical equality.
  Iterable<T> removeDuplicates() => RemoveDuplicatesIterable<T>(this);
}

extension IntInterableExtenions on Iterable<int> {
  Iterable<Span> toRanges() {
    final List<Span> result = <Span>[];
    int? previous;
    for (int i in this) {
      if (previous == null || i != previous + 1) {
        result.add(Span(i, i));
      } else {
        assert(result.isNotEmpty);
        final Span span = result.last;
        result[result.length - 1] = Span(span.start, i);
      }
      previous = i;
    }
    return result;
  }
}

class RemoveDuplicatesIterable<T> extends Iterable<T> {
  RemoveDuplicatesIterable(this._iterable);

  final Iterable<T> _iterable;

  @override
  Iterator<T> get iterator => RemoveDuplicatesIterator(_iterable.iterator);
}

class RemoveDuplicatesIterator<T> implements Iterator<T> {
  RemoveDuplicatesIterator(this._iterator);

  final Iterator<T> _iterator;
  final Set<T> _seen = <T>{};

  @override
  bool moveNext() {
    while (_iterator.moveNext()) {
      if (_seen.add(_iterator.current)) {
        return true;
      }
    }
    return false;
  }

  @override
  T get current => _iterator.current;
}
