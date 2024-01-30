import 'package:chicago/chicago.dart' show Span;

extension IterableExtensions<T> on Iterable<T> {
  /// Whether this collection has one and only one element.
  bool get isSingle => length == 1;

  /// Creates a new lazy [Iterable] with any duplicate items removed.
  ///
  /// Duplicate items are determined by logical equality.
  Iterable<T> removeDuplicates() {
    final Set<T> seen = <T>{};
    return where((T element) => seen.add(element));
  }
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
