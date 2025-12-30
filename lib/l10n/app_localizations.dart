import 'package:flutter/material.dart';
import 'package:n3rd_game/config/game_constants.dart';

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

  AppLocalizations(this.locale);
  final Locale locale;

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
  String get guest => 'Guest';
  String get userInitial => 'U';

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
  String get preparingGame => 'Preparing game...';
  String get initializingServices => 'Initializing services...';
  String get validatingSubscription => 'Validating subscription...';
  String get checkingGameAvailability => 'Checking game availability...';
  String get loadingGameSettings => 'Loading game settings...';
  String get startingGame => 'Starting game...';
  String get retrying => 'Retrying...';

  // Exception Messages
  // Authentication Exceptions
  String get userMustBeLoggedIn => 'User must be logged in';
  String get userMustBeLoggedInToCreateRoom =>
      'User must be logged in to create a room';
  String get userMustBeLoggedInToJoinRoom =>
      'User must be logged in to join a room';
  // Validation Exceptions
  String get invalidRoomIdFormat => 'Invalid room ID format';
  String get roomNotFound => 'Room not found';
  String get roomIsFull => 'Room is full';
  String get onlyHostCanStartGame => 'Only the host can start the game';
  String get notAllPlayersReady => 'Not all players are ready';
  String get onlyHostCanAssignRoles => 'Only the host can assign roles';
  String get playerNotInRoom => 'Player not in room';
  String get onlyHostCanAdvanceRounds => 'Only the host can advance rounds';
  String get onlyHostCanSendInvitations =>
      'Only the host can send invitations';
  String get friendAlreadyInvited => 'Friend already invited';
  String get invitationNotFound => 'Invitation not found';
  String get onlyInviterCanCancelInvitation =>
      'Only the inviter can cancel the invitation';
  String get directMessagingRequiresPremium =>
      'Direct messaging requires premium access';
  String get userNotAuthenticated => 'User not authenticated';
  String get messageCannotBeEmpty => 'Message cannot be empty';
  String get noActiveConversation => 'No active conversation';
  String get messageNotFound => 'Message not found';
  String get canOnlyDeleteOwnMessages =>
      'You can only delete your own messages';

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
  String get leaderboardLoadError =>
      'Failed to load leaderboard. Please try again.';
  String get loadMore => 'Load More';
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

  // Stats and Leaderboard
  String get gamesPlayed => 'Games Played';
  String get highestScore => 'Highest Score';
  String get accuracy => 'Accuracy';
  String get leaderboardView => 'Leaderboard';
  String get personalStatsView => 'Personal Stats';
  String get showPersonalStats => 'Show Personal Stats';
  String get showLeaderboard => 'Show Leaderboard';
  String get personalPerformance => 'Personal Performance';
  String get yourStats => 'Your Stats';
  String get lineChart => 'Line';
  String get barChart => 'Bar';
  String get areaChart => 'Area';

  // Onboarding
  String get onboardingWelcomeTitle => 'Welcome to N3RD Trivia';
  String get onboardingWelcomeDescription =>
      'Test your memory and knowledge with challenging trivia games.';
  String get onboardingFeaturesTitle => 'Features & Editions';
  String get onboardingFeaturesDescription =>
      'Access multiple trivia editions, AI-generated content, and personalized learning experiences.';
  String get onboardingPlayTitle => 'Play Solo or Online';
  String get onboardingPlayDescription =>
      'Challenge yourself or compete with friends in multiplayer matches.';
  String get onboardingProgressTitle => 'Track Your Progress';
  String get onboardingProgressDescription =>
      'View your stats, achievements, and climb the leaderboards.';
  String get onboardingGetStarted => 'Get Started';
  String get onboardingDontShowAgain => "Don't show again";
  String get onboardingSaveError =>
      'Failed to save onboarding status. Please try again.';

  // Settings & More Menu
  String get appName => 'N3RD Trivia';
  String get version => 'Version';
  String get appDescription =>
      'Test your memory and knowledge with challenging trivia games.';
  String get createdBy => 'Created by';
  String get avatarUploadComingSoon => 'Avatar upload coming soon';
  String get imagePickError => 'Failed to pick image. Please try again.';
  String get displayName => 'Display Name';
  String get gameSettingsNote => 'These settings affect your game experience';
  String get gameSettingsSaveError =>
      'Failed to save game settings. Please try again.';
  String get dataExportShareText => 'Share your data export';
  String get dataExportSuccess => 'Data exported successfully';
  String get dataExportFileNotFound => 'Export file not found';
  String get deleteAccountWarning =>
      'This action cannot be undone. All your data will be permanently deleted.';
  String get accountDeleteError =>
      'Failed to delete account. Please try again.';
  String get profileSubtitle => 'Edit profile and account settings';
  String get subscriptions => 'Subscriptions';
  String get subscriptionsSubtitle => 'Manage your subscription plans';
  String get features => 'Features';
  String get dailyChallenges => 'Daily Challenges';
  String get dailyChallengesSubtitle => 'Complete daily trivia challenges';
  String get learningModeSubtitle => 'Learn while you play';
  String get performanceInsightsSubtitle =>
      'View detailed performance analytics';
  String get practiceModeSubtitle => 'Practice without pressure';
  String get triviaCreator => 'Trivia Creator';
  String get triviaCreatorSubtitle => 'Create your own trivia questions';
  String get support => 'Support';
  String get helpCenter => 'Help Center';
  String get helpCenterSubtitle => 'Get help and answers';
  String get submitFeedback => 'Submit Feedback';
  String get submitFeedbackSubtitle => 'Share your thoughts and suggestions';
  String get settingsSubtitle => 'Customize your app experience';
  String get aboutN3rdTrivia => 'About N3RD Trivia';
  String get signOut => 'Sign Out';
  String get signOutSubtitle => 'Sign out of your account';
  String get signOutConfirm => 'Sign Out';
  String get signOutConfirmMessage => 'Are you sure you want to sign out?';
  String get signOutError => 'Failed to sign out. Please try again.';
  String get gameNotifications => 'Game Notifications';
  String get gameNotificationsSubtitle => 'Get notified about daily challenges';
  String get leaderboardUpdates => 'Leaderboard Updates';
  String get leaderboardUpdatesSubtitle => 'Get notified when you rank up';
  String get settingsSaveError => 'Failed to save setting. Please try again.';
  String get pushNotifications => 'Push Notifications';
  String get pushNotificationsSubtitle =>
      'Receive push notifications from the app';
  String get dailyReminders => 'Daily Reminders';
  String get dailyRemindersSubtitle => 'Remind me to play daily';
  String get achievementAlerts => 'Achievement Alerts';
  String get achievementAlertsSubtitle =>
      'Get notified when you unlock achievements';

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

  // Error messages (general)
  String get somethingWentWrong => 'Something went wrong';
  String get errorInconvenience =>
      'We\'re sorry for the inconvenience. Please try restarting the app.';
  String get goToHome => 'Go to Home';
  String get navigationError => 'Unable to navigate. Please try again.';
  String get gameStateRecovered => 'Game state recovered';

  // External service names
  String get googleSearch => 'Google Search';
  String get wikipedia => 'Wikipedia';
  String get dictionaryCom => 'Dictionary.com';
  String get merriamWebster => 'Merriam-Webster';

  // Service error messages
  String get couldNotOpenService => 'Could not open service';
  String get errorOpeningService => 'Error opening service';

  // Premium feature messages
  String get premiumFeatureDescription =>
      'Multiplayer games are available for Premium subscribers. Upgrade to access online multiplayer features!';

  // Multiplayer messages
  String get noInternetReconnecting =>
      'No internet connection. Reconnecting...';
  String get retryingSubmission => 'Retrying submission...';
  String get answerSubmittedSuccessfully => 'Answer submitted successfully!';
  String get pingSent => 'Ping sent!';

  // Friends & Social
  String get pleaseEnterValidEmail => 'Please enter a valid email address';
  String get pleaseEnterValidPhone => 'Please enter a valid phone number';
  String get add => 'Add';
  String get youMustBeSignedInToShareQR =>
      'You must be signed in to share your QR code';
  String get qrCodeSharedSuccessfully => 'QR code shared successfully!';
  String get userNotFound => 'User not found';
  String get friendRequestSent => 'Friend request sent!';
  String get noSuggestionsAvailable => 'No suggestions available at this time';
  String get pleaseEnterEmailAddress => 'Please enter an email address';
  String get inviteSharedSuccessfully => 'Invite shared successfully';
  String get userBlockedSuccessfully => 'User blocked successfully';
  String get pleaseFillInAllFields => 'Please fill in all fields';
  String get reportSubmittedThankYou => 'Report submitted. Thank you!';
  String get blockUser => 'Block User';
  String get enterEmailToBlock =>
      'Enter the email of the user you want to block.';
  String get emailAddressLabel => 'Email Address';
  String get enterUserEmailHint => 'Enter user\'s email';
  String get blockButton => 'Block';
  String get reportUser => 'Report User';
  String get userEmailLabel => 'User Email';
  String get reasonLabel => 'Reason';
  String get describeIssueHint => 'Describe the issue...';
  String get sendButton => 'Send';

  // Word of the Day
  String get checkingAuthentication => 'Checking authentication...';
  String get loadingWordOfTheDay => 'Loading word of the day...';
  String get unableToLoadWord => 'Unable to Load Word';
  String get wordOfTheDayLoadError =>
      'There was an error loading the word of the day. Please try again later.';

  // Game Mode Descriptions
  String get classicModeDescription =>
      'Study words for 10 seconds, then select the correct answers in 20 seconds. Perfect for beginners.';
  String get classicIIModeDescription =>
      'Faster-paced version: Study for 5 seconds, select answers in 10 seconds. For experienced players.';
  String get speedModeDescription =>
      'Words and question shown together. Answer quickly within 7 seconds. Test your reflexes!';
  String get regularModeDescription =>
      'Words and question shown together. Take your time with 15 seconds to answer. Great for learning.';
  String get shuffleModeDescription =>
      'Tiles continuously shuffle during play. Stay focused and find the correct answers!';
  String get challengeModeDescription =>
      'Difficulty increases each round. Can you survive the escalating challenge?';
  String get randomModeDescription =>
      'Experience a different game mode each round. Never know what\'s coming next!';
  String get timeAttackModeDescription =>
      'Score as many points as possible within 60 seconds. Race against the clock!';
  String get streakModeDescription =>
      'Score multiplier increases with each perfect round. Build your streak for maximum points!';
  String get blitzModeDescription =>
      'Ultra-fast mode: Study for 3 seconds, answer in 5 seconds. Only for the quickest minds!';
  String get marathonModeDescription =>
      'Infinite rounds with progressive difficulty. How long can you last?';
  String get perfectModeDescription =>
      'Must get all 3 answers correct. One wrong answer ends the game. Precision is key!';
  String get survivalModeDescription =>
      'Start with 1 life. Gain a life every 3 perfect rounds. Survive as long as possible!';
  String get precisionModeDescription =>
      'Wrong selection loses a life immediately. Perfect accuracy required to succeed!';
  String get flipModeDescription =>
      'Study for 10 seconds (4s visible, 6s flipping), then play for 20 seconds with face-down tiles.';
  String get aiModeDescription =>
      'AI adapts difficulty based on your performance. Personalized challenge that learns from you.';
  String get practiceModeDescription =>
      'No scoring, unlimited hints. Learn at your own pace without pressure.';
  String get learningModeDescription =>
      'Review questions you missed and improve your knowledge. Track your progress over time.';

  // Mode Selection Dialogs
  String get shuffleDifficulty => 'Shuffle Difficulty';
  String get flipModeRevealSetting => 'Flip Mode Reveal Setting';
  String get instantReveal => 'Instant';
  String get instantRevealDescription =>
      'Tiles reveal immediately when selected';
  String get blindReveal => 'Blind';
  String get blindRevealDescription => 'Select all 3, then reveal results';
  String get randomReveal => 'Random';
  String get randomRevealDescription => 'Random reveal mode each round';

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
      'Select ${GameConstants.expectedCorrectAnswers} correct answers';

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
  String get continueButton => 'Continue';
  String get manageSubscriptions => 'Manage Subscriptions';
  String get signOutTitle => 'Sign Out?';
  String get signOutConfirmation => 'Are you sure you want to sign out?';
  String get aboutN3RD => 'About N3RD';
  String get versionWithNumber => 'Version';
  String get createdByLabel => 'Created by';
  String releaseDate(String date) => date;
  String copyright(int year) => 'Copyright N3RD Trivia $year';

  // Account management
  String get deleteAccount => 'Delete Account';
  String get deleteAccountSubtitle => 'Permanently delete your account';
  String get profileUpdated => 'Profile updated';
  String get failedToUpdateProfile => 'Failed to update profile';
  String get pleaseEnterDisplayName => 'Please enter a display name';
  String get gameSettingsSaved => 'Game settings saved';
  String get accountDeletedSuccessfully => 'Account deleted successfully';
  String get backToMenu => 'Back to Menu';

  // Social features
  String get newsfeed => 'Newsfeed';
  String get discover => 'Discover';
  String get findPlayers => 'Find Players';
  String get trending => 'Trending';
  String get recommended => 'Recommended';
  String get searchPlayersHint => 'Search by name or email...';
  String get noActivities => 'No activities yet';
  String get noPlayersFound => 'No players found';
  String get refreshError => 'Unable to refresh. Please try again.';
  String get searchError => 'Search failed. Please try again.';
  String get sendRequestError =>
      'Failed to send friend request. Please try again.';

  // Error messages
  String get qrCodeGenerationError =>
      'Failed to generate QR code. Please try again.';
  String get qrCodeShareError => 'Failed to share QR code. Please try again.';
  String get genericError => 'An error occurred. Please try again.';
  String get loadingSuggestionsError =>
      'Failed to load suggestions. Please try again.';
  String get sendInviteError => 'Failed to send invite. Please try again.';
  String get submitReportError => 'Failed to submit report. Please try again.';
  String get startGameError => 'Failed to start game. Please try again.';

  // Additional error messages for user-facing errors
  String get triviaGenerationFailed =>
      'Failed to generate trivia content. Please try again.';
  String get conversationsRefreshError =>
      'Failed to refresh conversations. Please try again.';
  String get purchaseError => 'Purchase failed. Please try again.';
  String get dataExportError => 'Failed to export data. Please try again.';
  String get friendsRefreshError =>
      'Failed to refresh friends list. Please try again.';
  String get contactAccessUnavailable =>
      'Contact access unavailable. Searching users only.';
  String get friendsSearchError => 'Search failed. Please try again.';
  String get friendAddError => 'Failed to add friend. Please try again.';
  String get subscriptionError =>
      'Subscription operation failed. Please try again.';
  String get practiceModeError => 'Practice mode error. Please try again.';
  String get challengeNavigationError =>
      'Failed to start challenge. Please try again.';
  String get youthEditionError =>
      'Failed to load youth edition. Please try again.';
  String get goalsSaveError => 'Failed to save goals. Please try again.';
  String get calibrationStartError =>
      'Failed to start calibration. Please try again.';
  String get recordingError => 'Recording error. Please try again.';
  String get listeningError => 'Failed to start listening. Please try again.';
  String get recordingStopError =>
      'Failed to stop recording. Please try again.';

  // Voice Calibration UI Strings
  String get voiceCalibrationTitle => 'Voice Calibration';
  String get voiceCalibrationDescription =>
      'We\'ll ask you to speak 3 words, 3 times each. This helps us recognize your voice better.';
  String get startCalibration => 'Start Calibration';
  String get calibrationComplete => 'Calibration Complete!';
  String get calibrationSuccessMessage =>
      'Your voice profile has been created successfully.';
  String get calibrationLowAccuracyMessage =>
      'Calibration accuracy was too low. Please try again.';
  String get sayThisWord => 'Say this word:';
  String get sampleXOfY => 'Sample {current} of {total}';
  String get voiceRecognitionNotAvailableDevice =>
      'Voice recognition is not available on this device';
  String get noCalibrationWordAvailable =>
      'No calibration word available. Please try again.';
  String get heardText => 'Heard: "{text}"';
  String get calibrationInstructions =>
      'Hold the microphone button and speak the word clearly. Release when done.';
  String get voiceCalibrationStatusCalibrated =>
      'Voice recognition trained';
  String get voiceCalibrationStatusNotCalibrated =>
      'Train voice recognition for better accuracy';
  String get voiceCalibrationPromptTitle => 'Improve Voice Recognition';
  String get voiceCalibrationPromptMessage =>
      'Calibrate your voice for better word recognition accuracy.';
  String get calibrateNow => 'Calibrate Now';
  String get skipCalibration => 'Skip';
  String get calibrationAccuracyScore => 'Accuracy: {score}%';
  String get testCalibrationInGame => 'Test in Game';

  String get multiplayerLobbyError =>
      'Lobby operation failed. Please try again.';
  String get multiplayerRoundError =>
      'Round operation failed. Please try again.';
  String get multiplayerPingError => 'Failed to send ping. Please try again.';
  String get messageError => 'Message operation failed. Please try again.';
  String get familyOperationError =>
      'Family operation failed. Please try again.';
  String get familyInvitationError =>
      'Failed to process invitation. Please try again.';

  // Comprehensive error message mapping
  String getLocalizedErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return networkError;
    }
    if (errorStr.contains('timeout')) {
      return 'Request timed out. $tryAgain';
    }
    if (errorStr.contains('offline') || errorStr.contains('no internet')) {
      return connectionLost;
    }

    // Authentication errors
    if (errorStr.contains('authentication') ||
        errorStr.contains('sign in') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('unauthenticated')) {
      return 'Authentication failed. Please sign in again.';
    }
    if (errorStr.contains('permission') || errorStr.contains('access denied')) {
      return 'Permission denied. Please check your access rights.';
    }

    // Validation errors
    if (errorStr.contains('validation') || errorStr.contains('invalid')) {
      return 'Invalid input. Please check your information and try again.';
    }

    // Game/Trivia errors
    if (errorStr.contains('trivia') && errorStr.contains('generation')) {
      return triviaGenerationFailed;
    }
    if (errorStr.contains('no templates available') ||
        errorStr.contains('template initialization')) {
      return templateInitializationIssue;
    }
    if (errorStr.contains('unable to generate unique trivia') ||
        errorStr.contains('all content used')) {
      return allContentUsed;
    }
    if (errorStr.contains('trivia') && errorStr.contains('validation')) {
      return triviaValidationFailed;
    }
    if (errorStr.contains('trivia') && errorStr.contains('load')) {
      return failedToLoadTrivia;
    }

    // Subscription/Purchase errors
    if (errorStr.contains('subscription') || errorStr.contains('purchase')) {
      return subscriptionError;
    }
    if (errorStr.contains('payment') || errorStr.contains('billing')) {
      return purchaseError;
    }

    // Storage errors
    if (errorStr.contains('storage') ||
        errorStr.contains('save') ||
        errorStr.contains('write')) {
      return 'Failed to save data. Please try again.';
    }
    if (errorStr.contains('load') && errorStr.contains('data')) {
      return 'Failed to load data. Please try again.';
    }

    // Firebase/Firestore errors
    if (errorStr.contains('firebase') || errorStr.contains('firestore')) {
      if (errorStr.contains('permission-denied')) {
        return 'Permission denied. Please check your access rights.';
      }
      if (errorStr.contains('not-found')) {
        return 'Resource not found. Please try again.';
      }
      if (errorStr.contains('unavailable')) {
        return 'Service temporarily unavailable. $tryAgain';
      }
      return 'Database error. Please try again.';
    }

    // Default fallback
    return unknownError;
  }

  // Specific error messages for common exception types
  String get noTemplatesAvailableError =>
      'No trivia templates available. Please restart the app.';
  String get templateInitializationError => templateInitializationIssue;
  String get unableToGenerateTriviaError => allContentUsed;
  String get triviaGenerationError => triviaGenerationFailed;
  String get triviaLoadError => failedToLoadTrivia;
  String get authenticationError =>
      'Authentication failed. Please sign in again.';
  String get permissionError =>
      'Permission denied. Please check your access rights.';
  String get networkTimeoutError => 'Request timed out. $tryAgain';
  String get serviceUnavailableError =>
      'Service temporarily unavailable. $tryAgain';
  String get storageError => 'Failed to save data. Please try again.';
  String get dataLoadError => 'Failed to load data. Please try again.';
  String get databaseError => 'Database error. Please try again.';
  String get validationError =>
      'Invalid input. Please check your information and try again.';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Support for RTL languages: Arabic, Hebrew, Persian, Urdu
    // Currently returns English for all locales, but structure is ready for translations
    // To add translations, create locale-specific classes or use ARB files
    return AppLocalizations(locale);
  }

  @override
  bool isSupported(Locale locale) {
    // Support English and RTL languages
    return const [
      'en', // English
      'ar', // Arabic
      'he', // Hebrew
      'fa', // Persian (Farsi)
      'ur', // Urdu
    ].contains(locale.languageCode);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) =>
      true; // Reload when locale changes
}
