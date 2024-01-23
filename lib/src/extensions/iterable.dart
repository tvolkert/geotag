import 'package:chicago/chicago.dart' show Span;

extension IterableExtensions<T> on Iterable<T> {
  bool get isSingle => length == 1;
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
