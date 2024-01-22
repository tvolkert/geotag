import 'package:chicago/chicago.dart' show Span;
import 'package:flutter_test/flutter_test.dart';
import 'package:geotag/src/extensions/iterable.dart';

void main() {
  test('toRanges', () {
    expect(<int>[].toRanges(), const <Span>[]);
    expect(<int>[1, 2, 3].toRanges(), const <Span>[Span(1, 3)]);
    expect(<int>[1, 2, 4, 5].toRanges(), const <Span>[Span(1, 2), Span(4, 5)]);
    expect(<int>[4, 5, 1, 2].toRanges(), const <Span>[Span(4, 5), Span(1, 2)]);
  });
}
