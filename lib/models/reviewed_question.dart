class ReviewedQuestion {
  final String questionId;
  final String category;
  final List<String> words;
  final List<String> correctAnswers;
  final List<String> userAnswers;
  final bool wasCorrect;
  final DateTime answeredAt;
  final int roundNumber;
  final String gameMode;
  final bool isBookmarked;

  ReviewedQuestion({
    required this.questionId,
    required this.category,
    required this.words,
    required this.correctAnswers,
    required this.userAnswers,
    required this.wasCorrect,
    required this.answeredAt,
    required this.roundNumber,
    required this.gameMode,
    this.isBookmarked = false,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'category': category,
    'words': words,
    'correctAnswers': correctAnswers,
    'userAnswers': userAnswers,
    'wasCorrect': wasCorrect,
    'answeredAt': answeredAt.toIso8601String(),
    'roundNumber': roundNumber,
    'gameMode': gameMode,
    'isBookmarked': isBookmarked,
  };

  factory ReviewedQuestion.fromJson(Map<String, dynamic> json) =>
      ReviewedQuestion(
        questionId: json['questionId'] as String,
        category: json['category'] as String,
        words: List<String>.from(json['words'] as List),
        correctAnswers: List<String>.from(json['correctAnswers'] as List),
        userAnswers: List<String>.from(json['userAnswers'] as List),
        wasCorrect: json['wasCorrect'] as bool,
        answeredAt: DateTime.parse(json['answeredAt'] as String),
        roundNumber: json['roundNumber'] as int,
        gameMode: json['gameMode'] as String,
        isBookmarked: json['isBookmarked'] as bool? ?? false,
      );

  ReviewedQuestion copyWith({
    String? questionId,
    String? category,
    List<String>? words,
    List<String>? correctAnswers,
    List<String>? userAnswers,
    bool? wasCorrect,
    DateTime? answeredAt,
    int? roundNumber,
    String? gameMode,
    bool? isBookmarked,
  }) {
    return ReviewedQuestion(
      questionId: questionId ?? this.questionId,
      category: category ?? this.category,
      words: words ?? this.words,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      userAnswers: userAnswers ?? this.userAnswers,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      answeredAt: answeredAt ?? this.answeredAt,
      roundNumber: roundNumber ?? this.roundNumber,
      gameMode: gameMode ?? this.gameMode,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
