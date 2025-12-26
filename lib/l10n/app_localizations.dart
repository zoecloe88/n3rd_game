import 'package:flutter/material.dart';
import 'package:n3rd_game/services/game_service.dart';

/// Localization support for N3RD Trivia
///
/// This class provides localized strings for the application.
/// Currently supports English (en) as the default locale.
///
/// **Usage:**
/// ```dart
/// AppLocalizations.of(context)!.appTitle
/// ```
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Common strings
  String get appTitle => 'N3RD Trivia';
  String get loading => 'Loading...';
  String get error => 'Error';
  String get success => 'Success';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get save => 'Save';
  String get delete => 'Delete';
  String get edit => 'Edit';
  String get close => 'Close';
  String get back => 'Back';
  String get next => 'Next';
  String get previous => 'Previous';
  String get done => 'Done';
  String get skip => 'Skip';
  String get retry => 'Retry';
  String get ok => 'OK';
  String get yes => 'Yes';
  String get no => 'No';

  // Navigation
  String get home => 'Home';
  String get play => 'Play';
  String get multiplayer => 'Multiplayer';
  String get leaderboard => 'Leaderboard';
  String get settings => 'Settings';
  String get profile => 'Profile';
  String get friends => 'Friends';
  String get addFriend => 'Add Friend';
  String get achievements => 'Achievements';
  String get stats => 'Statistics';
  String get analytics => 'Advanced Analytics';
  String get performanceInsights => 'Performance Insights';
  String get help => 'Help';
  String get about => 'About';

  // Game
  String get gameOver => 'Game Over';
  String get score => 'Score';
  String get round => 'Round';
  String get lives => 'Lives';
  String get correct => 'Correct';
  String get incorrect => 'Incorrect';
  String get submit => 'Submit';
  String get hint => 'Hint';
  String get nextRound => 'Next Round';
  String get startGame => 'Start Game';
  String get pauseGame => 'Pause Game';
  String get resumeGame => 'Resume Game';
  String get exitGame => 'Exit Game';
  String get exitGameConfirmation =>
      'Are you sure you want to exit? Your progress will be lost.';

  // Modes
  String get classicMode => 'Classic';
  String get speedMode => 'Speed';
  String get shuffleMode => 'Shuffle';
  String get timeAttackMode => 'Time Attack';
  String get flipMode => 'Flip';
  String get practiceMode => 'Practice';
  String get learningMode => 'Learning';

  // Multiplayer
  String get createRoom => 'Create Room';
  String get joinRoom => 'Join Room';
  String get leaveRoom => 'Leave Room';
  String get waitingForPlayers => 'Waiting for players...';
  String get playersReady => 'Players Ready';
  String get gameStarting => 'Game Starting...';
  String get chat => 'Chat';
  String get sendMessage => 'Send Message';
  String get typeMessage => 'Type a message...';

  // Subscription
  String get premium => 'Premium';
  String get free => 'Free';
  String get upgrade => 'Upgrade';
  String get subscription => 'Subscription';
  String get manageSubscription => 'Manage Subscription';
  String get premiumFeature => 'Premium Feature';
  String get upgradeRequired => 'Upgrade Required';
  String get upgradeToPremium => 'Upgrade to Premium';
  String get upgradeModeDescription =>
      'This game mode is only available with Basic or Premium subscription. Upgrade to unlock all game modes!';
  String get viewPlans => 'View Plans';

  // Errors
  String get networkError => 'Network error. Please check your connection.';
  String get unknownError => 'An unknown error occurred.';
  String get tryAgain => 'Please try again.';
  String get connectionLost => 'Connection lost. Attempting to reconnect...';
  String get operationFailed => 'Operation failed.';

  // Empty states
  String get noFriends => 'No friends yet';
  String get noFriendsDescription => 'Add friends to compete and chat!';
  String get noLeaderboard => 'No leaderboard data';
  String get noLeaderboardDescription =>
      'Be the first to play and set a record!';
  String get noChatMessages => 'No messages yet';
  String get noChatMessagesDescription => 'Start a conversation!';
  String get noTriviaHistory => 'No trivia history';
  String get noTriviaHistoryDescription =>
      'Play some games to see your history!';
  String get noChallenges => 'No challenges available';
  String get noChallengesDescription =>
      'Check back tomorrow for new challenges!';
  String get noAchievements => 'No achievements yet';
  String get noAchievementsDescription =>
      'Keep playing to unlock achievements!';
  String get noStats => 'No statistics yet';
  String get noStatsDescription => 'Play games to see your statistics!';

  // Accessibility
  String get backButton => 'Back button';
  String get closeButton => 'Close button';
  String get menuButton => 'Menu button';
  String get settingsButton => 'Settings button';
  String get playButton => 'Play button';
  String get pauseButton => 'Pause button';
  String get submitButton => 'Submit button';
  String get hintButton => 'Hint button';
  String get nextButton => 'Next button';
  String get previousButton => 'Previous button';
  String get saveButton => 'Save button';
  String get deleteButton => 'Delete button';
  String get editButton => 'Edit button';
  String get cancelButton => 'Cancel button';
  String get confirmButton => 'Confirm button';
  String get retryButton => 'Retry button';
  String get okButton => 'OK button';
  String get yesButton => 'Yes button';
  String get noButton => 'No button';

  // Instructions screen
  String get howToPlay => 'How to Play';
  String get memorizeTheWords => 'Memorize the Words';
  String get memorizeTheWordsDescription =>
      'Study the words shown to you during the memorization phase. Pay attention to the correct answers!';
  String get select3CorrectAnswers => 'Select 3 Correct Answers';
  String get select3CorrectAnswersDescription =>
      'From the shuffled list, choose exactly 3 words that match the correct answers you memorized.';
  String get scorePoints => 'Score Points';
  String get scorePointsDescription =>
      'Earn points based on how many correct answers you select:\n• 1 correct = 10 points\n• 2 correct = 20 points\n• 3 correct = 30 points';
  String get tryDifferentModes => 'Try Different Modes';
  String get tryDifferentModesDescription =>
      'Explore various game modes:\n• Classic: Standard timing\n• Speed: Fast-paced challenges\n• Shuffle: Tiles move during play\n• Time Attack: Score as much as possible in 60 seconds';
  String get proTips => 'Pro Tips';
  String get tipFocusCategory => 'Focus on the category to understand context';
  String get tipTimeManagement => 'Time management is key in speed modes';
  String get tipPracticeClassic => 'Practice with Classic mode first';
  String get tipWatchLives =>
      'Watch your lives - you lose one for zero correct answers';

  // Error messages
  String get noTriviaContentAvailable =>
      'No trivia content available after multiple attempts. This may indicate a temporary issue. Please try again or restart the app.';
  String get triviaValidationFailed =>
      'Trivia content validation failed. Please restart the app or contact support if this persists.';
  String get failedToLoadTrivia => 'Failed to load trivia content.';
  String get templateInitializationIssue =>
      'Template initialization issue detected. Please restart the app.';
  String get allContentUsed =>
      'All available content has been used. Try clearing history or selecting a different theme.';
  String get checkConnectionAndRetry =>
      'Please check your connection and try again.';
  String get passwordMinLength => 'Password must be at least 8 characters long';
  String get passwordMaxLength => 'Password must be less than 128 characters';
  String get passwordUppercase =>
      'Password must contain at least one uppercase letter';
  String get passwordLowercase =>
      'Password must contain at least one lowercase letter';
  String get passwordNumber => 'Password must contain at least one number';
  String get passwordSpecialChar =>
      'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
  String get passwordCommonWeak =>
      'Password is too common. Please choose a stronger password';

  // Game Instructions
  String get instructionHowToPlayTitle => 'How to Play';
  String get instructionHowToPlayMessage =>
      'Tap once on a tile to reveal and select it as an answer.\n\nSelect exactly 3 correct answers to win the round.';
  String get instructionSelectThreeTitle => 'Select 3 Answers';
  String get instructionSelectThreeMessage =>
      'You need to select exactly 3 correct answers to win the round.\n\nPerfect rounds give you +30 points!';
  String get instructionTimeManagementTitle => 'Time Management';
  String get instructionTimeManagementMessage =>
      'Watch the timer! In Classic mode, you have 10 seconds to memorize and 20 seconds to select.\n\nTime runs out? Your current selections will be submitted automatically.';
  String get instructionShuffleModeTitle => 'Shuffle Mode Tip';
  String get instructionShuffleModeMessage =>
      'In Shuffle mode, tiles will move around during play!\n\nTap to reveal and select quickly before they shuffle again.';
  String get instructionSpeedModeTitle => 'Speed Mode';
  String get instructionSpeedModeMessage =>
      'Speed mode shows all words immediately—no memorization phase!\n\nYou have just 7 seconds to select 3 correct answers. Think fast!';
  String get instructionLivesSystemTitle => 'Lives System';
  String get instructionLivesSystemMessage =>
      'You start with 3 lives (❤️).\n\nGet 0 correct answers and you lose a life. Run out of lives and it\'s game over!';
  String get instructionScoringTitle => 'Scoring';
  String get instructionScoringMessage =>
      'Perfect round (3/3): +30 points\n\nPartial (1-2/3): +10 points per correct answer\n\nWrong (0/3): Lose a life';
  String get instructionRevealStrategyTitle => 'Reveal Strategy';
  String get instructionRevealStrategyMessage =>
      'Tip: Reveal tiles strategically!\n\nTap tiles you\'re unsure about first, then select the ones you know are correct.';
  String get instructionPlayPhaseMessage =>
      'Select ${GameService.expectedCorrectAnswers} correct answers';

  // Additional game strings
  String get gotIt => 'Got it';
  String get exit => 'Exit';
  String get exitChallenge => 'Exit Challenge?';
  String get exitChallengeMessage =>
      'Your progress will be saved, but your score won\'t be submitted to the leaderboard.';
  String get gameSettings => 'Game settings';
  String get memorizeTheseWillShuffle => 'Memorize—these will shuffle';
  String get memorizeTheseWords => 'Memorize these words';

  // Difficulty levels
  String get easy => 'Easy';
  String get medium => 'Medium';
  String get hard => 'Hard';
  String get insane => 'Insane';
  String get slowShuffles => 'Slow shuffles';
  String get moderateShuffles => 'Moderate shuffles';
  String get fastShuffles => 'Fast shuffles';
  String get chaosMode => 'Chaos mode';

  // Settings
  String get n3rdPlayer => 'N3RD Player';
  String get editProfile => 'Edit Profile';
  String get editProfileSubtitle => 'Update display name and avatar';
  String get emailSettings => 'Email Settings';
  String get emailSettingsSubtitle => 'Manage email notifications';
  String get notifications => 'Notifications';
  String get notificationsSubtitle => 'Push notifications and reminders';
  String get achievementsSubtitle => 'View your achievements and badges';
  String get leaderboardSubtitle => 'View global rankings';
  String get soundAndMusic => 'Sound & Music';
  String get soundAndMusicSubtitle => 'Adjust audio settings';
  String get voiceSettings => 'Voice Settings';
  String get voiceSettingsSubtitle => 'Text-to-speech and voice input';
  String get voiceCalibration => 'Voice Calibration';
  String get voiceCalibrationSubtitle => 'Train voice recognition';
  String get appearance => 'Appearance';
  String get appearanceSubtitle => 'Theme and display settings';
  String get language => 'Language';
  String get languageSubtitle => 'Change app language';
  String get gameSettingsTitle => 'Game Settings';
  String get gameSettingsSubtitle => 'Customize gameplay experience';
  String get privacyPolicy => 'Privacy Policy';
  String get privacyPolicySubtitle => 'Read our privacy policy';
  String get termsOfService => 'Terms of Service';
  String get termsOfServiceSubtitle => 'Read our terms of service';
  String get exportData => 'Export Data';
  String get exportDataSubtitle => 'Download your data';
  String get account => 'Account';
  String get premiumFeatures => 'Premium Features';
  String get preferences => 'Preferences';
  String get dataAndPrivacy => 'Data & Privacy';

  // Title screen
  String get wordOfTheDay => 'Word of the Day';
  String get editions => 'Editions';
  String get gameHistory => 'Game History';

  // Account management
  String get deleteAccount => 'Delete Account';
  String get deleteAccountSubtitle => 'Permanently delete your account';
  String get profileUpdated => 'Profile updated';
  String get failedToUpdateProfile => 'Failed to update profile';
  String get pleaseEnterDisplayName => 'Please enter a display name';
  String get gameSettingsSaved => 'Game settings saved';
  String get accountDeletedSuccessfully => 'Account deleted successfully';
  String get backToMenu => 'Back to Menu';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'fr', 'de'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true; // Reload when locale changes
}
