import 'dart:math';

import 'package:fl_clash/common/fixed.dart';
import 'package:test/test.dart';

void main() {
  group('FixedList', () {
    test('rejects an uncapped list', () {
      expect(() => FixedList<int>(0), throwsA(isA<AssertionError>()));
    });

    test('respects maxLength on creation', () {
      final list = FixedList(3, list: [1, 2, 3, 4, 5]);
      expect(list.length, 3);
      expect(list.list, [3, 4, 5]);
    });

    test('truncates when adding beyond maxLength', () {
      final list = FixedList(3);
      list.add(1);
      list.add(2);
      list.add(3);
      list.add(4);
      expect(list.list, [2, 3, 4]);
    });

    test('clear empties the list', () {
      final list = FixedList(3, list: [1, 2, 3]);
      list.clear();
      expect(list.length, 0);
      expect(list.list, isEmpty);
    });

    test('copyWith creates independent copy', () {
      final original = FixedList(3, list: [1, 2, 3]);
      final copy = original.copyWith();
      copy.add(4);
      expect(original.list, [1, 2, 3]);
      expect(copy.list, [2, 3, 4]);
    });

    test('operator [] returns correct element', () {
      final list = FixedList(5, list: [10, 20, 30]);
      expect(list[0], 10);
      expect(list[2], 30);
    });

    test('list getter returns unmodifiable view', () {
      final list = FixedList(3, list: [1, 2, 3]);
      final view = list.list;
      expect(() => view.add(4), throwsA(isA<UnsupportedError>()));
    });

    test('list caches the snapshot until the next mutation', () {
      final list = FixedList(3, list: [1, 2]);
      expect(identical(list.list, list.list), isTrue);
      list.add(3);
      expect(list.list, [1, 2, 3]);
    });

    test('append yields a new generation over the same buffer', () {
      final first = FixedList(3, list: [1, 2]);
      final second = first.append(3);
      expect(second.list, [1, 2, 3]);
      expect(second.revision, first.revision + 1);
    });

    test('append makes the wrapper unequal so listeners are notified', () {
      final first = FixedList(3, list: [1, 2]);
      expect(first == first.copyWith(), isFalse, reason: 'distinct buffers');
      expect(first == first.append(3), isFalse, reason: 'distinct generations');
    });

    test('a snapshot taken before append is unaffected by it', () {
      final first = FixedList(3, list: [1, 2]);
      final before = first.list;
      first.append(3);
      expect(before, [1, 2]);
    });

    test('replace swaps items in a new generation', () {
      final first = FixedList(3, list: [1, 2, 3]);
      final before = first.list;
      final second = first.replace({0: 10, 2: 30});
      expect(second.list, [10, 2, 30]);
      expect(second.revision, first.revision + 1);
      expect(before, [1, 2, 3]);
    });

    test('append still honours maxLength', () {
      var list = FixedList<int>(2);
      for (var i = 1; i <= 4; i++) {
        list = list.append(i);
      }
      expect(list.list, [3, 4]);
    });

    test('wraps repeatedly without changing logical indices or snapshots', () {
      var list = FixedList<int>(3);
      for (var i = 0; i < 20; i++) {
        list = list.append(i);
      }
      final before = list.list;
      expect([list[0], list[1], list[2]], [17, 18, 19]);
      list = list.replace({0: 170, 2: 190});
      expect(list.list, [170, 18, 190]);
      final copy = list.copyWith();
      list = list.append(20);
      expect(list.list, [18, 190, 20]);
      expect(copy.list, [170, 18, 190]);
      expect(before, [17, 18, 19]);
      list.clear();
      list.add(21);
      expect(list.list, [21]);
      expect(() => list[-1], throwsRangeError);
      expect(() => list[1], throwsRangeError);
      expect(() => list.replace({-1: 0}), throwsRangeError);
      expect(() => list.replace({1: 0}), throwsRangeError);
      list.clear();
      expect(() => list[0], throwsRangeError);
    });

    test('supports nullable values and a capacity of one', () {
      final list = FixedList<int?>(1, list: [1]);
      list.add(null);
      expect(list[0], isNull);
      expect(list.list, [null]);
      list.add(2);
      expect(list.list, [2]);
    });

    test('generations share the ring position as well as its contents', () {
      final first = FixedList<int>(3, list: [1, 2, 3]);
      final second = first.append(4);
      final held = second.list;
      final firstSnapshot = first.list;
      final third = second.append(5);
      expect(first[0], 3);
      expect(third.list, [3, 4, 5]);
      expect(held, [2, 3, 4]);
      expect(firstSnapshot, [2, 3, 4]);
      expect(first.copyWith().list, [3, 4, 5]);
      expect(third.revision, 2);
    });

    test('matches bounded list semantics across mixed operations', () {
      final random = Random(42);
      for (final capacity in [1, 2, 31, 3000]) {
        var actual = FixedList<int>(capacity);
        final expected = <int>[];
        for (var i = 0; i < capacity * 3 + 200; i++) {
          final before = actual.list;
          final beforeValues = List.of(expected);
          final revision = actual.revision;
          if (random.nextInt(30) == 0) {
            actual.clear();
            expected.clear();
          } else if (expected.isNotEmpty && random.nextInt(5) == 0) {
            final index = random.nextInt(expected.length);
            actual = actual.replace({index: -i});
            expected[index] = -i;
            expect(actual.revision, revision + 1);
          } else {
            actual = actual.append(i);
            expected.add(i);
            if (expected.length > capacity) expected.removeAt(0);
            expect(actual.revision, revision + 1);
          }
          expect(actual.list, expected);
          expect(before, beforeValues);
          expect(actual.length, expected.length);
        }
      }
    });
  });

  group('retainTrimmedHead', () {
    final items = List.generate(6, (i) => Object());

    test('passes latest through when nothing was trimmed', () {
      final current = items.sublist(0, 3);
      final latest = items.sublist(0, 5);
      expect(retainTrimmedHead(current, latest, 10), same(latest));
      expect(retainTrimmedHead(<Object>[], latest, 10), same(latest));
    });

    test('restores entries trimmed off the front', () {
      final current = items.sublist(0, 4);
      final latest = items.sublist(2, 6);
      expect(retainTrimmedHead(current, latest, 10), items);
    });

    test('keeps everything current when latest is entirely newer', () {
      final current = items.sublist(0, 2);
      final latest = items.sublist(4, 6);
      expect(retainTrimmedHead(current, latest, 10), [...current, ...latest]);
    });

    test('finds where latest starts by key when it carries a copy', () {
      final current = [(1, 'a'), (2, 'a'), (3, 'a'), (4, 'a')];
      final latest = [(3, 'b'), (4, 'a'), (5, 'a')];
      expect(retainTrimmedHead(current, latest, 10, keyOf: (item) => item.$1), [
        (1, 'a'),
        (2, 'a'),
        (3, 'b'),
        (4, 'a'),
        (5, 'a'),
      ]);
    });

    test('caps growth from the tail', () {
      final current = items.sublist(0, 4);
      final latest = items.sublist(2, 6);
      expect(retainTrimmedHead(current, latest, 5), items.sublist(0, 5));
    });
  });
}
