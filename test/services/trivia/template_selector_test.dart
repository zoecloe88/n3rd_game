import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/trivia/template_selector.dart';

void main() {
  group('TemplateSelector', () {
    late TemplateSelector selector;

    setUp(() {
      selector = TemplateSelector();
    });

    test('selects template from list', () {
      final templates = [
        TriviaTemplate(
          categoryPattern: 'Test Category',
          correctPool: ['word1', 'word2'],
          distractorPool: ['distractor1', 'distractor2'],
          theme: 'general',
        ),
      ];

      final selected = selector.selectTemplate(templates);
      expect(selected, isNotNull);
      expect(selected, equals(templates.first));
    });

    test('returns null for empty list', () {
      final selected = selector.selectTemplate([]);
      expect(selected, isNull);
    });

    test('filters by theme when provided', () {
      final templates = [
        TriviaTemplate(
          categoryPattern: 'Category 1',
          correctPool: ['word1'],
          distractorPool: ['dist1'],
          theme: 'science',
        ),
        TriviaTemplate(
          categoryPattern: 'Category 2',
          correctPool: ['word2'],
          distractorPool: ['dist2'],
          theme: 'history',
        ),
      ];

      final selected = selector.selectTemplate(templates, theme: 'science');
      expect(selected, isNotNull);
      expect(selected?.theme, 'science');
    });

    test('selects multiple templates', () {
      final templates = List.generate(
        5,
        (i) => TriviaTemplate(
          categoryPattern: 'Category $i',
          correctPool: ['word$i'],
          distractorPool: ['dist$i'],
          theme: 'general',
        ),
      );

      final selected = selector.selectTemplates(templates, count: 3);
      expect(selected.length, 3);
      expect(selected.toSet().length, 3); // All unique
    });

    test('returns empty list for zero count', () {
      final templates = [
        TriviaTemplate(
          categoryPattern: 'Test',
          correctPool: ['word'],
          distractorPool: ['dist'],
          theme: 'general',
        ),
      ];

      final selected = selector.selectTemplates(templates, count: 0);
      expect(selected, isEmpty);
    });
  });
}

