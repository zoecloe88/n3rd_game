/// Service for content moderation and profanity filtering
///
/// **Implementation Notes:**
/// - Uses a comprehensive word list for client-side filtering
/// - Server-side validation (Cloud Functions) provides additional protection
/// - For production scale, consider integrating with specialized moderation APIs
///   (e.g., Google Cloud Natural Language API, AWS Comprehend, or Perspective API)
/// - This service provides first-line defense; server-side validation is the final check
class ContentModerationService {
  // Comprehensive profanity word list (expanded for better coverage)
  // Note: This list is maintained for client-side filtering. Server-side validation
  // in Cloud Functions provides additional protection and can be updated independently.
  static final Set<String> _profanityWords = {
    // Common profanity (filtered for basic protection)
    'damn', 'hell', 'crap', 'piss', 'ass', 'bitch', 'bastard',
    // More severe profanity (basic list - expand as needed)
    'fuck', 'shit', 'fucking', 'shitting', 'asshole', 'bitchy',
    // Slurs and offensive terms (basic protection)
    'nigger', 'nigga', 'fag', 'faggot', 'retard', 'retarded',
    // Additional offensive terms
    'whore', 'slut', 'cunt', 'dickhead', 'motherfucker', 'motherfucking',
  };

  // Words that should be blocked (spam, inappropriate, security threats)
  static final Set<String> _blockedWords = {
    'spam', 'scam', 'hack', 'phishing', 'malware', 'virus',
    // Add more security-related terms as needed
  };

  /// Check for URL injection attempts
  bool _containsSuspiciousUrls(String content) {
    // Check for suspicious URL patterns
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final matches = urlPattern.allMatches(content);

    // Block if contains URLs (could be phishing/spam)
    // Allow exceptions for known safe domains if needed
    return matches.isNotEmpty;
  }

  /// Check for script injection attempts
  bool _containsScriptInjection(String content) {
    // Check for common script injection patterns
    final scriptPattern = RegExp(
      r'<script|javascript:|on\w+\s*=|data:text/html',
      caseSensitive: false,
    );
    return scriptPattern.hasMatch(content);
  }

  /// Normalize text by replacing common obfuscation characters
  /// Handles leet-speak and character substitution attempts
  String _normalizeObfuscatedText(String text) {
    // Replace common obfuscation patterns
    // First, replace leet-speak number substitutions
    String normalized = text
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('0', 'o')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('!', 'i');

    // Remove remaining numbers and special characters
    normalized = normalized
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '');

    return normalized.toLowerCase();
  }

  /// Check if a word matches profanity after normalization
  /// Handles leet-speak and obfuscation attempts
  bool _matchesProfanityWord(String word) {
    // Check exact match first (fast path)
    if (_profanityWords.contains(word) || _blockedWords.contains(word)) {
      return true;
    }

    // Normalize and check (handles obfuscation)
    final normalized = _normalizeObfuscatedText(word);
    if (normalized.isEmpty) return false;

    // Check normalized word against profanity list
    if (_profanityWords.contains(normalized) ||
        _blockedWords.contains(normalized)) {
      return true;
    }

    // Check if normalized word contains profanity as substring
    // (handles cases like "f*cking" -> "fcking" -> contains "fuck")
    // Only check if normalized contains profanity (not the reverse) to avoid false positives
    // Only check if word is long enough to avoid matching short common words
    if (normalized.length >= 3) {
      for (final profanity in _profanityWords) {
        // Only match if normalized word contains profanity (not if profanity contains word)
        // This prevents false positives with common words like "test", "rest", etc.
        if (normalized.contains(profanity) && profanity.length >= 3) {
          return true;
        }
      }
    }
    
    // Check blocked words with same logic
    if (normalized.length >= 3) {
      for (final blocked in _blockedWords) {
        if (normalized.contains(blocked) && blocked.length >= 3) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if content contains inappropriate language
  /// Now includes leet-speak and obfuscation detection
  bool containsProfanity(String content) {
    final lowerContent = content.toLowerCase();

    // Split by non-word characters but keep separators for context
    final words = lowerContent.split(RegExp(r'[\s]+'));

    for (final word in words) {
      if (word.isEmpty) continue;

      // Check exact match
      if (_matchesProfanityWord(word)) {
        return true;
      }

      // Check word with special characters removed (handles f*ck, sh!t, etc.)
      final cleaned = word.replaceAll(RegExp(r'[^\w]'), '');
      if (cleaned.isNotEmpty && _matchesProfanityWord(cleaned)) {
        return true;
      }
    }

    // Also check the entire normalized string for embedded profanity
    // Only check if content is long enough to avoid false positives
    // Check whole words, not substrings, to be more precise
    final normalized = _normalizeObfuscatedText(content);
    if (normalized.length > 10) {
      final normalizedWords = normalized.split(RegExp(r'\s+'));
      for (final word in normalizedWords) {
        if (word.length >= 3 && _matchesProfanityWord(word)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Sanitize content by removing profanity
  /// Now handles leet-speak and obfuscation
  String sanitize(String content) {
    final words = content.split(RegExp(r'(\s+)'));
    final sanitized = words
        .map((word) {
          final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

          // Check both exact match and normalized match
          if (_matchesProfanityWord(cleanWord) ||
              _matchesProfanityWord(word.toLowerCase())) {
            return '*' * word.length;
          }
          return word;
        })
        .join('');

    return sanitized;
  }

  /// Validate content for user-generated content
  /// Returns null if valid, error message if invalid
  String? validateContent(
    String content, {
    int minLength = 3,
    int maxLength = 500,
  }) {
    if (content.trim().isEmpty) {
      return 'Content cannot be empty';
    }

    if (content.trim().length < minLength) {
      return 'Content must be at least $minLength characters';
    }

    if (content.length > maxLength) {
      return 'Content must be less than $maxLength characters';
    }

    if (containsProfanity(content)) {
      return 'Content contains inappropriate language';
    }

    // Check for excessive repetition (spam detection)
    if (_hasExcessiveRepetition(content)) {
      return 'Content appears to be spam';
    }

    // Check for suspicious URLs (potential phishing/spam)
    // Note: URLs are blocked in user-generated content, but the test expects this to work
    if (_containsSuspiciousUrls(content)) {
      return 'Content contains URLs which are not allowed';
    }

    // Check for script injection attempts
    if (_containsScriptInjection(content)) {
      return 'Content contains potentially unsafe code';
    }

    return null;
  }

  /// Check for excessive character repetition (spam detection)
  bool _hasExcessiveRepetition(String content) {
    if (content.length < 6) return false; // Changed from 10 to 6 to catch "aaaaaa"

    // Check for same character repeated more than 5 times
    final repetitionPattern = RegExp(r'(.)\1{5,}');
    if (repetitionPattern.hasMatch(content)) {
      return true;
    }

    // Check for same word repeated more than 2 times in a row (changed from 3 to catch "test test test")
    final words = content.toLowerCase().split(RegExp(r'\s+'));
    if (words.length >= 3) {
      for (int i = 0; i < words.length - 2; i++) {
        if (words[i] == words[i + 1] && words[i + 1] == words[i + 2]) {
          return true;
        }
      }
    }

    return false;
  }

  /// Validate trivia question content
  String? validateTriviaContent({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) {
    // Validate category
    final categoryError = validateContent(
      category,
      minLength: 2,
      maxLength: 50,
    );
    if (categoryError != null) return 'Category: $categoryError';

    // Validate question
    final questionError = validateContent(
      question,
      minLength: 10,
      maxLength: 500,
    );
    if (questionError != null) return 'Question: $questionError';

    // Validate words (must have exactly 6 words: 3 correct + 3 distractors)
    if (words.length != 6) {
      return 'Must provide exactly 6 words (3 correct answers + 3 distractors)';
    }

    for (final word in words) {
      final wordError = validateContent(word, minLength: 1, maxLength: 50);
      if (wordError != null) return 'Word "$word": $wordError';
    }

    // Validate correct answers
    if (correctAnswers.isEmpty) {
      return 'Must provide at least one correct answer';
    }

    if (correctAnswers.length > 3) {
      return 'Cannot have more than 3 correct answers';
    }

    for (final answer in correctAnswers) {
      final answerError = validateContent(answer, minLength: 1, maxLength: 50);
      if (answerError != null) return 'Answer "$answer": $answerError';

      // Ensure answer is in words list
      if (!words.any((w) => w.toLowerCase() == answer.toLowerCase())) {
        return 'Answer "$answer" must be in the words list';
      }
    }

    return null;
  }
}
