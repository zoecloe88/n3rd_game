import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/game/game_persistence_manager.dart';
import 'package:n3rd_game/models/game_state.dart';
import 'package:n3rd_game/models/game_mode_config.dart';
import '../../utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamePersistenceManager', () {
    late GamePersistenceManager manager;

    setUpAll(() async {
      TestHelpers.setupMockSharedPreferences();
    });

    tearDownAll(() {
      TestHelpers.clearMockSharedPreferences();
    });

    setUp(() {
      manager = GamePersistenceManager();
    });

    test('should initialize with no saved state', () async {
      final result = await manager.loadState();
      expect(result, isNull);
    });

    test('should save and load core state', () async {
      final coreState = GameState(
        score: 100,
        lives: 2,
        round: 3,
        isGameOver: false,
        perfectStreak: 2,
      );

      await manager.saveState(
        coreState: coreState,
        extendedState: null,
      );

      final loaded = await manager.loadState();
      expect(loaded, isNotNull);
      expect(loaded!['coreState'], isA<GameState>());
      final loadedState = loaded['coreState'] as GameState;
      expect(loadedState.score, 100);
      expect(loadedState.lives, 2);
      expect(loadedState.round, 3);
    });

    test('should save and load extended state', () async {
      final coreState = GameState(
        score: 50,
        lives: 3,
        round: 1,
        isGameOver: false,
      );

      const extendedState = ExtendedGameState(
        revealAllUses: 3,
        clearUses: 2,
        skipUses: 1,
        streakShieldUses: 0,
        timeFreezeUses: 0,
        hintUses: 0,
        doubleScoreUses: 0,
        currentMode: GameMode.classic,
        streakMultiplier: 1,
        survivalPerfectCount: 0,
        isTimeFrozen: false,
        hasDoubleScore: false,
        hasStreakShield: false,
        sessionCorrectAnswers: 5,
        sessionWrongAnswers: 2,
        phase: GamePhase.memorize,
        shuffledWords: ['word1', 'word2'],
        selectedAnswers: [],
        revealedWords: [],
        memorizeTimeLeft: 10,
        playTimeLeft: 20,
        currentTriviaPool: [],
        flipModeSelectedOrder: [],
        flipCurrentIndex: 0,
        flippedTiles: [],
        hintedWords: [],
        shuffleCount: 0,
        isShuffling: false,
        shuffleDifficulty: 'medium',
      );

      await manager.saveState(
        coreState: coreState,
        extendedState: extendedState,
      );

      final loaded = await manager.loadState();
      expect(loaded, isNotNull);
      expect(loaded!['extendedState'], isA<ExtendedGameState>());
    });

    test('should clear state', () async {
      final coreState = GameState(
        score: 100,
        lives: 2,
        round: 1,
        isGameOver: false,
      );

      await manager.saveState(coreState: coreState, extendedState: null);
      expect(await manager.loadState(), isNotNull);

      await manager.clearState();
      expect(await manager.loadState(), isNull);
    });

    test('should track save failure notifications', () {
      expect(manager.needsSaveFailureNotification, false);
      expect(manager.needsExtendedStateFailureNotification, false);
    });

    test('should reset notification flags', () {
      manager.resetNotificationFlags();
      expect(manager.needsSaveFailureNotification, false);
      expect(manager.needsExtendedStateFailureNotification, false);
    });
  });
}
