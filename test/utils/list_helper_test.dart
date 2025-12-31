// Copyright (c) 2025 Girard Clairsaint. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/utils/list_helper.dart';

void main() {
  group('ListHelper', () {
    group('safeFirst', () {
      test('should return first element when list is not empty', () {
        final list = [1, 2, 3];
        expect(ListHelper.safeFirst(list), equals(1));
      });

      test('should return null when list is empty', () {
        final list = <int>[];
        expect(ListHelper.safeFirst(list), isNull);
      });

      test('should return null when list is null', () {
        expect(ListHelper.safeFirst<int>(null), isNull);
      });

      test('should work with string lists', () {
        final list = ['a', 'b', 'c'];
        expect(ListHelper.safeFirst(list), equals('a'));
      });
    });

    group('safeLast', () {
      test('should return last element when list is not empty', () {
        final list = [1, 2, 3];
        expect(ListHelper.safeLast(list), equals(3));
      });

      test('should return null when list is empty', () {
        final list = <int>[];
        expect(ListHelper.safeLast(list), isNull);
      });

      test('should return null when list is null', () {
        expect(ListHelper.safeLast<int>(null), isNull);
      });

      test('should work with string lists', () {
        final list = ['a', 'b', 'c'];
        expect(ListHelper.safeLast(list), equals('c'));
      });
    });

    group('safeElementAt', () {
      test('should return element at valid index', () {
        final list = [1, 2, 3];
        expect(ListHelper.safeElementAt(list, 0), equals(1));
        expect(ListHelper.safeElementAt(list, 1), equals(2));
        expect(ListHelper.safeElementAt(list, 2), equals(3));
      });

      test('should return null when index is out of bounds', () {
        final list = [1, 2, 3];
        expect(ListHelper.safeElementAt(list, 3), isNull);
        expect(ListHelper.safeElementAt(list, -1), isNull);
      });

      test('should return null when list is null', () {
        expect(ListHelper.safeElementAt<int>(null, 0), isNull);
      });

      test('should return null when list is empty', () {
        final list = <int>[];
        expect(ListHelper.safeElementAt(list, 0), isNull);
      });
    });

    group('safeSingle', () {
      test('should return element when list has exactly one element', () {
        final list = [42];
        expect(ListHelper.safeSingle(list), equals(42));
      });

      test('should return null when list is empty', () {
        final list = <int>[];
        expect(ListHelper.safeSingle(list), isNull);
      });

      test('should return null when list has more than one element', () {
        final list = [1, 2];
        expect(ListHelper.safeSingle(list), isNull);
      });

      test('should return null when list is null', () {
        expect(ListHelper.safeSingle<int>(null), isNull);
      });
    });

    group('isNotEmpty', () {
      test('should return true when list is not empty', () {
        final list = [1, 2, 3];
        expect(ListHelper.isNotEmpty(list), isTrue);
      });

      test('should return false when list is empty', () {
        final list = <int>[];
        expect(ListHelper.isNotEmpty(list), isFalse);
      });

      test('should return false when list is null', () {
        expect(ListHelper.isNotEmpty<int>(null), isFalse);
      });
    });

    group('isEmpty', () {
      test('should return false when list is not empty', () {
        final list = [1, 2, 3];
        expect(ListHelper.isEmpty(list), isFalse);
      });

      test('should return true when list is empty', () {
        final list = <int>[];
        expect(ListHelper.isEmpty(list), isTrue);
      });

      test('should return true when list is null', () {
        expect(ListHelper.isEmpty<int>(null), isTrue);
      });
    });
  });
}
