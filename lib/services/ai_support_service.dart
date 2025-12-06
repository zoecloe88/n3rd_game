import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AI-powered support service that provides intelligent responses and troubleshooting
/// Uses rule-based AI with pattern matching and context awareness
class AISupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get AI-generated response based on user query
  Future<AISupportResponse> getAIResponse({
    required String userQuery,
    String? context, // Additional context like screen name, error message
    Map<String, dynamic>? userData, // User stats, subscription status, etc.
  }) async {
    try {
      final lowerQuery = userQuery.toLowerCase();

      // Analyze query intent
      final intent = _analyzeIntent(lowerQuery, context);

      // Get response based on intent
      final response = _generateResponse(intent, userQuery, userData);

      // Log interaction for learning
      _logInteraction(userQuery, intent, response);

      return response;
    } catch (e) {
      debugPrint('Error generating AI response: $e');
      return AISupportResponse(
        message:
            'I apologize, but I\'m having trouble processing your request. '
            'Please try rephrasing your question or contact support directly.',
        confidence: 0.5,
        suggestedActions: ['Contact Support', 'Check Help Center'],
        relatedTopics: [],
      );
    }
  }

  /// Analyze user intent from query
  String _analyzeIntent(String query, String? context) {
    // Authentication issues
    if (query.contains('login') ||
        query.contains('sign in') ||
        query.contains('password') ||
        query.contains('account')) {
      return 'authentication';
    }

    // Gameplay issues
    if (query.contains('game') ||
        query.contains('play') ||
        query.contains('round') ||
        query.contains('tile') ||
        query.contains('score') ||
        query.contains('points')) {
      return 'gameplay';
    }

    // Technical issues
    if (query.contains('crash') ||
        query.contains('error') ||
        query.contains('bug') ||
        query.contains('broken') ||
        query.contains('not working') ||
        query.contains('freeze')) {
      return 'technical';
    }

    // Subscription/Payment
    if (query.contains('subscription') ||
        query.contains('premium') ||
        query.contains('payment') ||
        query.contains('purchase') ||
        query.contains('tier') ||
        query.contains('token')) {
      return 'subscription';
    }

    // Feature questions
    if (query.contains('how') ||
        query.contains('what') ||
        query.contains('where') ||
        query.contains('when') ||
        query.contains('feature') ||
        query.contains('can i')) {
      return 'feature_inquiry';
    }

    // Performance
    if (query.contains('slow') ||
        query.contains('lag') ||
        query.contains('performance') ||
        query.contains('speed')) {
      return 'performance';
    }

    // General help
    return 'general';
  }

  /// Generate response based on intent
  AISupportResponse _generateResponse(
    String intent,
    String originalQuery,
    Map<String, dynamic>? userData,
  ) {
    switch (intent) {
      case 'authentication':
        return AISupportResponse(
          message:
              'I can help with login issues. Here are common solutions:\n\n'
              '1. **Check your credentials** - Make sure your email and password are correct\n'
              '2. **Reset password** - Use the "Forgot Password" option if available\n'
              '3. **Check connection** - Ensure you have a stable internet connection\n'
              '4. **Account status** - Verify your account is still active\n\n'
              'If these don\'t work, try signing out and signing back in.',
          confidence: 0.9,
          suggestedActions: [
            'Reset Password',
            'Check Internet Connection',
            'Contact Support',
          ],
          relatedTopics: ['Login', 'Account Recovery', 'Password Reset'],
        );

      case 'gameplay':
        final isPremium = userData?['isPremium'] ?? false;
        final hasTokens = userData?['hasTokens'] ?? true;

        return AISupportResponse(
          message:
              'Here\'s how to improve your gameplay:\n\n'
              '**Scoring System:**\n'
              '• Each correct answer = 10 points\n'
              '• Perfect round (3/3) = +10 bonus points\n'
              '• Wrong answer = -1 life\n\n'
              '**Power-Ups:**\n'
              '• Start with 3 Reveal All, 3 Clear, 3 Skip\n'
              '• ${isPremium ? "Premium users get: Streak Shield, Time Freeze, Hint, Double Score" : "Upgrade to Premium for advanced power-ups"}\n\n'
              '**Streak Rewards:**\n'
              '• 3rd perfect streak = 1 life\n'
              '• 6th = 1 skip\n'
              '• 9th = 1 clear\n'
              '• 12th = 1 reveal\n\n'
              '${hasTokens ? "" : "⚠️ Free tier limit reached. You get 5 games per day (resets at midnight UTC)."}',
          confidence: 0.95,
          suggestedActions: [
            'View Quick Tips',
            'Check Stats',
            isPremium ? null : 'Upgrade to Premium',
          ].whereType<String>().toList(),
          relatedTopics: ['Scoring', 'Power-Ups', 'Game Modes', 'Strategies'],
        );

      case 'technical':
        return AISupportResponse(
          message:
              'I\'m sorry you\'re experiencing technical issues. Let\'s troubleshoot:\n\n'
              '**Quick Fixes:**\n'
              '1. **Restart the app** - Close completely and reopen\n'
              '2. **Restart device** - This fixes many issues\n'
              '3. **Check updates** - Make sure app is up to date\n'
              '4. **Clear cache** - Go to Settings > Clear Cache\n'
              '5. **Check storage** - Ensure you have enough space\n\n'
              '**If problem persists:**\n'
              '• Submit a bug report with screenshots\n'
              '• Include what you were doing when it happened\n'
              '• Note your device model and OS version',
          confidence: 0.85,
          suggestedActions: [
            'Submit Bug Report',
            'Check App Updates',
            'Contact Support',
          ],
          relatedTopics: ['Troubleshooting', 'Bug Reports', 'Performance'],
        );

      case 'subscription':
        final subscriptionStatus = userData?['subscriptionStatus'] ?? 'none';

        return AISupportResponse(
          message:
              'Here\'s information about subscriptions:\n\n'
              '**Subscription Tiers:**\n'
              '• **Free:** 5 games/day, Classic mode only\n'
              '• **Basic (\$2.99/month):** All modes (except AI), unlimited play, no ads\n'
              '• **Premium (\$4.99/month):** Everything + AI mode + editions + online features\n\n'
              '**Your Status:** ${_formatSubscriptionStatus(subscriptionStatus)}\n\n'
              '**Features:**\n'
              '• Tokens reset monthly\n'
              '• Each token lasts 24 hours\n'
              '• Premium includes voice input, TTS, advanced power-ups\n\n'
              'Need help with billing or want to upgrade?',
          confidence: 0.9,
          suggestedActions: [
            'Manage Subscription',
            'View Plans',
            'Restore Purchases',
            'Contact Billing Support',
          ],
          relatedTopics: ['Pricing', 'Features', 'Billing', 'Tokens'],
        );

      case 'feature_inquiry':
        return AISupportResponse(
          message:
              'Here are some key features you might be interested in:\n\n'
              '**Game Features:**\n'
              '• Multiple game modes (Classic, Speed, Shuffle, Challenge, etc.)\n'
              '• Power-ups and streak rewards\n'
              '• Daily challenges and achievements\n'
              '• Global leaderboards (Premium)\n\n'
              '**Learning Features:**\n'
              '• Word of the Day\n'
              '• Learning Mode (review missed questions)\n'
              '• Word info lookup (tap info icon on tiles)\n\n'
              '**Social Features:**\n'
              '• Connect with friends\n'
              '• Direct messaging\n'
              '• Multiplayer games (Premium)\n\n'
              'What specific feature would you like to know more about?',
          confidence: 0.8,
          suggestedActions: [
            'Explore Features',
            'View Help Center',
            'Check Tutorials',
          ],
          relatedTopics: [
            'Game Modes',
            'Power-Ups',
            'Social Features',
            'Learning',
          ],
        );

      case 'performance':
        return AISupportResponse(
          message:
              'To improve app performance:\n\n'
              '**Device Optimization:**\n'
              '• Close other apps to free memory\n'
              '• Restart device regularly\n'
              '• Keep device software updated\n'
              '• Clear device cache\n\n'
              '**App Optimization:**\n'
              '• Clear app cache in Settings\n'
              '• Reduce background processes\n'
              '• Check available storage (need 500MB+)\n'
              '• Disable unnecessary animations\n\n'
              '**Network:**\n'
              '• Use stable Wi-Fi when possible\n'
              '• Check connection speed\n'
              '• Avoid peak usage times',
          confidence: 0.85,
          suggestedActions: ['Clear Cache', 'Check Storage', 'Optimize Device'],
          relatedTopics: ['Performance', 'Optimization', 'Troubleshooting'],
        );

      default:
        return AISupportResponse(
          message:
              'I\'m here to help! I can assist with:\n\n'
              '• Gameplay questions and strategies\n'
              '• Technical issues and troubleshooting\n'
              '• Subscription and billing questions\n'
              '• Feature explanations\n'
              '• Account and login help\n\n'
              'What would you like to know? You can also check the Help Center for detailed guides.',
          confidence: 0.7,
          suggestedActions: [
            'Browse Help Center',
            'View Quick Tips',
            'Contact Support',
          ],
          relatedTopics: ['Getting Started', 'FAQ', 'Support'],
        );
    }
  }

  String _formatSubscriptionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'premium':
        return 'Premium - Full access ✅';
      case 'base':
        return 'Base - All game modes ✅';
      case 'free':
        return 'Free - Limited access';
      default:
        return 'No active subscription';
    }
  }

  /// Log interaction for learning (can be used to improve AI)
  void _logInteraction(
    String query,
    String intent,
    AISupportResponse response,
  ) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      _firestore.collection('ai_support_logs').add({
        'userId': user?.uid ?? 'anonymous',
        'query': query,
        'intent': intent,
        'response': response.message,
        'confidence': response.confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to log AI interaction: $e');
      // Don't throw - logging failure shouldn't break the feature
    }
  }

  /// Get support analytics for dashboard
  Future<Map<String, dynamic>> getSupportAnalytics() async {
    try {
      // Get common issues
      final issuesSnapshot = await _firestore
          .collection('feedback')
          .where('status', isEqualTo: 'new')
          .limit(100)
          .get();

      final issuesByType = <String, int>{};
      for (final doc in issuesSnapshot.docs) {
        final type = doc.data()['type'] ?? 'unknown';
        issuesByType[type] = (issuesByType[type] ?? 0) + 1;
      }

      // Get AI interaction stats
      final aiLogsSnapshot = await _firestore
          .collection('ai_support_logs')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final intentsCount = <String, int>{};
      for (final doc in aiLogsSnapshot.docs) {
        final intent = doc.data()['intent'] ?? 'unknown';
        intentsCount[intent] = (intentsCount[intent] ?? 0) + 1;
      }

      return {
        'totalIssues': issuesSnapshot.docs.length,
        'issuesByType': issuesByType,
        'totalAIInteractions': aiLogsSnapshot.docs.length,
        'intentsCount': intentsCount,
        'avgConfidence': aiLogsSnapshot.docs.isNotEmpty
            ? aiLogsSnapshot.docs
                      .map((d) => d.data()['confidence'] ?? 0.0)
                      .reduce((a, b) => a + b) /
                  aiLogsSnapshot.docs.length
            : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting support analytics: $e');
      return {
        'totalIssues': 0,
        'issuesByType': {},
        'totalAIInteractions': 0,
        'intentsCount': {},
        'avgConfidence': 0.0,
      };
    }
  }
}

/// AI Support Response model
class AISupportResponse {
  final String message;
  final double confidence; // 0.0 to 1.0
  final List<String> suggestedActions;
  final List<String> relatedTopics;

  AISupportResponse({
    required this.message,
    required this.confidence,
    required this.suggestedActions,
    required this.relatedTopics,
  });
}
