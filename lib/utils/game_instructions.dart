// ignore_for_file: undefined_getter
// Localization getters are optional - fallback strings are provided via ?? operator

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/game_service.dart';

/// Game instruction messages and tips system
class GameInstructions {
  static const String _prefPrefix = 'dont_show_instruction_';

  /// Get all available instruction messages (localized)
  static List<InstructionMessage> getAllInstructions(BuildContext? context) {
    final localizations = context != null ? AppLocalizations.of(context) : null;

    return [
      InstructionMessage(
        id: 'double_tap',
        title: localizations?.instructionHowToPlayTitle ?? 'How to Play',
        message:
            localizations?.instructionHowToPlayMessage ??
            'Tap once on a tile to reveal and select it as an answer.\n\nSelect exactly ${GameService.expectedCorrectAnswers} correct answers to win the round.',
        showOnce: true,
      ),
      InstructionMessage(
        id: 'select_three',
        title: localizations?.instructionSelectThreeTitle ?? 'Select 3 Answers',
        message:
            localizations?.instructionSelectThreeMessage ??
            'You need to select exactly ${GameService.expectedCorrectAnswers} correct answers to win the round.\n\nPerfect rounds give you +${GameService.expectedCorrectAnswers * 10} points!',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'time_management',
        title:
            localizations?.instructionTimeManagementTitle ?? 'Time Management',
        message:
            localizations?.instructionTimeManagementMessage ??
            'Watch the timer! In Classic mode, you have 10 seconds to memorize and 20 seconds to select.\n\nTime runs out? Your current selections will be submitted automatically.',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'shuffle_mode',
        title: localizations?.instructionShuffleModeTitle ?? 'Shuffle Mode Tip',
        message:
            localizations?.instructionShuffleModeMessage ??
            'In Shuffle mode, tiles will move around during play!\n\nTap to reveal and select quickly before they shuffle again.',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'speed_mode',
        title: localizations?.instructionSpeedModeTitle ?? 'Speed Mode',
        message:
            localizations?.instructionSpeedModeMessage ??
            'Speed mode shows all words immediately—no memorization phase!\n\nYou have just 7 seconds to select ${GameService.expectedCorrectAnswers} correct answers. Think fast!',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'lives_system',
        title: localizations?.instructionLivesSystemTitle ?? 'Lives System',
        message:
            localizations?.instructionLivesSystemMessage ??
            'You start with 3 lives (❤️).\n\nGet 0 correct answers and you lose a life. Run out of lives and it\'s game over!',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'scoring',
        title: localizations?.instructionScoringTitle ?? 'Scoring',
        message:
            localizations?.instructionScoringMessage ??
            'Perfect round (${GameService.expectedCorrectAnswers}/${GameService.expectedCorrectAnswers}): +${GameService.expectedCorrectAnswers * 10} points\n\nPartial (1-${GameService.expectedCorrectAnswers - 1}/${GameService.expectedCorrectAnswers}): +10 points per correct answer\n\nWrong (0/${GameService.expectedCorrectAnswers}): Lose a life',
        showOnce: false,
      ),
      InstructionMessage(
        id: 'reveal_strategy',
        title:
            localizations?.instructionRevealStrategyTitle ?? 'Reveal Strategy',
        message:
            localizations?.instructionRevealStrategyMessage ??
            'Tip: Reveal tiles strategically!\n\nTap tiles you\'re unsure about first, then select the ones you know are correct.',
        showOnce: false,
      ),
      // Classic II Mode
      const InstructionMessage(
        id: 'classic_ii_mode',
        title: 'Classic II Mode',
        message:
            'Classic II is faster than Classic mode!\n\nYou have 5 seconds to memorize and 10 seconds to select.\n\nPerfect for quick games when you\'re short on time.',
        showOnce: false,
      ),
      // Regular Mode
      const InstructionMessage(
        id: 'regular_mode',
        title: 'Regular Mode',
        message:
            'Regular mode shows all words immediately—no memorization phase!\n\nYou have 15 seconds to select ${GameService.expectedCorrectAnswers} correct answers.\n\nMore time than Speed mode, but still fast-paced!',
        showOnce: false,
      ),
      // Random Mode
      const InstructionMessage(
        id: 'random_mode',
        title: 'Random Mode',
        message:
            'Random mode changes the game mode each round!\n\nYou might get Classic, Speed, Shuffle, or any other mode.\n\nStay on your toes—adaptability is key!',
        showOnce: false,
      ),
      // Time Attack Mode
      const InstructionMessage(
        id: 'time_attack_mode',
        title: 'Time Attack Mode',
        message:
            'Time Attack: Score as much as possible in 60 seconds!\n\nNo rounds—just continuous play.\n\nEach correct answer adds to your score. How high can you go?',
        showOnce: false,
      ),
      // Challenge Mode
      const InstructionMessage(
        id: 'challenge_mode',
        title: 'Challenge Mode',
        message:
            'Challenge mode gets harder each round!\n\nRound 1: 12s memorize, 18s play\nRound 2: 10s memorize, 15s play\nRound 3+: Even faster!\n\nCan you survive the increasing difficulty?',
        showOnce: false,
      ),
      // Streak Mode
      const InstructionMessage(
        id: 'streak_mode',
        title: 'Streak Mode',
        message:
            'Streak mode rewards perfect rounds with score multipliers!\n\nEach perfect round increases your multiplier.\n\nBuild a streak to maximize your score!',
        showOnce: false,
      ),
      // Blitz Mode
      const InstructionMessage(
        id: 'blitz_mode',
        title: 'Blitz Mode',
        message:
            'Blitz mode is ultra-fast!\n\nYou have just 3 seconds to memorize and 5 seconds to select.\n\nOnly for the quickest minds!',
        showOnce: false,
      ),
      // Marathon Mode
      const InstructionMessage(
        id: 'marathon_mode',
        title: 'Marathon Mode',
        message:
            'Marathon mode: Infinite rounds with progressive difficulty!\n\nEarly rounds: 10s memorize, 20s play\nLater rounds: Faster and faster!\n\nHow long can you last?',
        showOnce: false,
      ),
      // Perfect Mode
      const InstructionMessage(
        id: 'perfect_mode',
        title: 'Perfect Mode',
        message:
            'Perfect mode: Zero tolerance for mistakes!\n\nYou must get all ${GameService.expectedCorrectAnswers} correct answers.\n\nOne wrong answer = game over. Precision is everything!',
        showOnce: false,
      ),
      // Survival Mode
      const InstructionMessage(
        id: 'survival_mode',
        title: 'Survival Mode',
        message:
            'Survival mode: Start with just 1 life!\n\nGain an extra life every 3 perfect rounds.\n\nCan you build your lives and survive?',
        showOnce: false,
      ),
      // Precision Mode
      const InstructionMessage(
        id: 'precision_mode',
        title: 'Precision Mode',
        message:
            'Precision mode: Wrong selection = lose life immediately!\n\nUnlike other modes, you lose a life as soon as you select a wrong answer.\n\nThink carefully before tapping!',
        showOnce: false,
      ),
      // Flip Mode
      const InstructionMessage(
        id: 'flip_mode',
        title: 'Flip Mode',
        message:
            'Flip Mode: Memory challenge!\n\nStudy phase (10s): Tiles are visible for 4 seconds, then flip face-down one by one over 6 seconds.\n\nPlay phase (20s): All tiles are face-down. Tap them in the correct order you saw them!\n\nThis tests your memory and attention!',
        showOnce: true,
      ),
      // AI Mode
      const InstructionMessage(
        id: 'ai_mode',
        title: 'AI Mode',
        message:
            'AI Mode: Adaptive difficulty that learns from you!\n\nThe AI adjusts timing and difficulty based on your performance.\n\nGet better? It gets harder. Struggling? It adapts to help you learn.\n\nPremium feature: Perfect for personalized learning!',
        showOnce: true,
      ),
      // Practice Mode
      const InstructionMessage(
        id: 'practice_mode',
        title: 'Practice Mode',
        message:
            'Practice Mode: Learn at your own pace!\n\n• No scoring or lives\n• Unlimited hints\n• Extended time (15s memorize, 30s play)\n• Review correct answers after each round\n\nPremium feature: Perfect for learning without pressure!',
        showOnce: true,
      ),
      // Learning Mode
      const InstructionMessage(
        id: 'learning_mode',
        title: 'Learning Mode',
        message:
            'Learning Mode: Review and improve!\n\n• Focus on questions you\'ve missed before\n• Extended time to think (15s memorize, 30s play)\n• Learn from mistakes\n• Build confidence\n\nPremium feature: Master the content you struggle with!',
        showOnce: true,
      ),
    ];
  }

  /// Get instruction ID for a specific game mode
  /// Returns null if no specific instruction exists for the mode
  static String? getInstructionIdForMode(GameMode mode) {
    switch (mode) {
      case GameMode.classicII:
        return 'classic_ii_mode';
      case GameMode.regular:
        return 'regular_mode';
      case GameMode.random:
        return 'random_mode';
      case GameMode.timeAttack:
        return 'time_attack_mode';
      case GameMode.challenge:
        return 'challenge_mode';
      case GameMode.streak:
        return 'streak_mode';
      case GameMode.blitz:
        return 'blitz_mode';
      case GameMode.marathon:
        return 'marathon_mode';
      case GameMode.perfect:
        return 'perfect_mode';
      case GameMode.survival:
        return 'survival_mode';
      case GameMode.precision:
        return 'precision_mode';
      case GameMode.flip:
        return 'flip_mode';
      case GameMode.ai:
        return 'ai_mode';
      case GameMode.practice:
        return 'practice_mode';
      case GameMode.learning:
        return 'learning_mode';
      case GameMode.shuffle:
        return 'shuffle_mode';
      case GameMode.speed:
        return 'speed_mode';
      case GameMode.classic:
        // Classic mode uses the basic 'double_tap' instruction
        return null;
    }
  }

  /// Get instruction by ID (localized)
  static InstructionMessage? getInstruction(String id, BuildContext? context) {
    try {
      return getAllInstructions(context).firstWhere((inst) => inst.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if instruction should be shown
  static Future<bool> shouldShowInstruction(
    String id, {
    BuildContext? context,
  }) async {
    // Capture instruction before async gap
    final instruction = getInstruction(id, context);
    if (instruction == null) return false;

    final prefs = await SharedPreferences.getInstance();

    // If showOnce is true, check if already shown
    if (instruction.showOnce) {
      final alreadyShown = prefs.getBool('$_prefPrefix$id') ?? false;
      return !alreadyShown;
    }

    // For non-showOnce instructions, check if user disabled it
    final dontShow = prefs.getBool('$_prefPrefix$id') ?? false;
    return !dontShow;
  }

  /// Mark instruction as shown/disabled
  static Future<void> markInstructionShown(
    String id, {
    bool dontShowAgain = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix$id', dontShowAgain);
  }

  /// Get random helpful tip (excluding already-shown showOnce instructions)
  static Future<InstructionMessage?> getRandomTip(BuildContext? context) async {
    // Capture instructions before async gap
    final allInsts = getAllInstructions(context);
    final available = <InstructionMessage>[];
    for (final inst in allInsts) {
      if (await shouldShowInstruction(inst.id, context: context)) {
        available.add(inst);
      }
    }
    if (available.isEmpty) return null;
    final index = DateTime.now().millisecondsSinceEpoch % available.length;
    return available[index];
  }
}

/// Instruction message model
class InstructionMessage {
  final String id;
  final String title;
  final String message;
  final bool showOnce;

  const InstructionMessage({
    required this.id,
    required this.title,
    required this.message,
    this.showOnce = false,
  });
}
