import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_trivia_manager.dart';
import 'package:n3rd_game/models/trivia_item.dart';

void main() {
  group('GameTriviaManager', () {
    late GameTriviaManager manager;

    setUp(() {
      manager = GameTriviaManager();
    });

    tearDown(() {
      // Manager doesn't require disposal, but keeping structure consistent
    });

    test('should initialize with empty pool', () {
      expect(manager.isPoolEmpty, true);
      expect(manager.poolSize, 0);
      expect(manager.recentCategories, isEmpty);
    });

    test('should set and get trivia pool', () {
      final pool = [
        TriviaItem(
          category: 'Test Category 1',
          words: ['word1', 'word2', 'word3'],
          correctAnswers: ['word1'],
        ),
        TriviaItem(
          category: 'Test Category 2',
          words: ['word4', 'word5', 'word6'],
          correctAnswers: ['word4'],
        ),
      ];

      manager.setTriviaPool(pool);
      expect(manager.poolSize, 2);
      expect(manager.isPoolEmpty, false);
      expect(manager.currentTriviaPool.length, 2);
    });

    test('should clear trivia pool', () {
      final pool = [
        TriviaItem(
          category: 'Test',
          words: ['word1'],
          correctAnswers: ['word1'],
        ),
      ];
      manager.setTriviaPool(pool);
      expect(manager.poolSize, 1);

      manager.clearTriviaPool();
      expect(manager.isPoolEmpty, true);
      expect(manager.poolSize, 0);
    });

    test('should track recent categories', () {
      manager.addRecentCategory('Category 1');
      expect(manager.recentCategories.length, 1);
      expect(manager.recentCategories.first, 'Category 1');

      manager.addRecentCategory('Category 2');
      expect(manager.recentCategories.length, 2);
      expect(manager.recentCategories.first, 'Category 2'); // Newest first
    });

    test('should check if category is recent', () {
      manager.addRecentCategory('Category 1');
      expect(manager.isCategoryRecent('Category 1'), true);
      expect(manager.isCategoryRecent('Category 2'), false);
    });

    test('should limit recent categories to max', () {
      for (int i = 0; i < 15; i++) {
        manager.addRecentCategory('Category $i');
      }
      expect(
        manager.recentCategories.length,
        GameTriviaManager.maxRecentCategories,
      );
    });

    test('should clear recent categories', () {
      manager.addRecentCategory('Category 1');
      manager.addRecentCategory('Category 2');
      expect(manager.recentCategories.length, 2);

      manager.clearRecentCategories();
      expect(manager.recentCategories, isEmpty);
    });

    test('should have trivia items in pool after setting', () {
      final pool = [
        TriviaItem(
          category: 'Category 1',
          words: ['word1', 'word2'],
          correctAnswers: ['word1'],
        ),
        TriviaItem(
          category: 'Category 2',
          words: ['word3', 'word4'],
          correctAnswers: ['word3'],
        ),
      ];
      manager.setTriviaPool(pool);

      expect(manager.currentTriviaPool.length, 2);
      expect(manager.currentTriviaPool.first.category, 'Category 1');
    });
  });
}
