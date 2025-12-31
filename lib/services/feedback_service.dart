import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:io' as io;
import 'package:n3rd_game/services/rate_limiter_service.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/utils/security_helper.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/firebase_helper.dart';

/// Service for handling user feedback, bug reports, and error submissions
class FeedbackService {
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for FeedbackService', error: e);
      return null;
    }
  }

  /// Get Storage instance if Firebase is available
  FirebaseStorage? get _storageInstance {
    if (_storage != null) return _storage;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _storage = FirebaseStorage.instance;
      return _storage;
    } catch (e) {
      LoggerService.debug('Firebase not available for FeedbackService', error: e);
      return null;
    }
  }

  final RateLimiterService _rateLimiter = RateLimiterService();
  final ContentModerationService _contentModeration =
      ContentModerationService();

  /// Submit feedback with optional images
  Future<void> submitFeedback({
    required String type, // 'bug', 'feature', 'error', 'question'
    required String message,
    String? category,
    List<File>? images,
    Map<String, dynamic>? deviceInfo,
    String? userEmail,
  }) async {
    try {
      final user = FirebaseHelper.getCurrentUser();
      final userId = user?.uid ?? 'anonymous';

      // Check rate limit for feedback submission
      final isAllowed = await _rateLimiter.isAllowed(
        'feedback_$userId',
        maxAttempts: 10,
        window: const Duration(hours: 1),
      );

      if (!isAllowed) {
        throw ValidationException(
          'Too many feedback submissions. Please try again later.',
        );
      }

      // Validate and sanitize message
      final sanitizedMessage = InputSanitizer.sanitizeText(message);

      final validationError = _contentModeration.validateContent(
        sanitizedMessage,
        minLength: 10,
        maxLength: 2000,
      );

      if (validationError != null) {
        throw ValidationException(validationError);
      }

      // Upload images if provided
      final List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        const maxImageSize = 5 * 1024 * 1024; // 5MB
        const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

        for (int i = 0; i < images.length; i++) {
          try {
            final imageFile = images[i];
            if (!imageFile.existsSync()) {
              LoggerService.debug('Image file does not exist: ${imageFile.path}');
              continue;
            }

            // Check file size
            final fileSize = await imageFile.length();

            // Security: Validate file upload
            final originalFileName = imageFile.path.split('/').last;
            if (!SecurityHelper.validateFileUpload(
              fileName: originalFileName,
              fileSize: fileSize.toInt(),
              allowedExtensions: allowedExtensions,
              maxSizeBytes: maxImageSize,
            )) {
              throw ValidationException(
                'Image $i is invalid. Please use JPG, PNG, GIF, or WebP format and ensure file size is under 5MB.',
              );
            }

            if (fileSize > maxImageSize) {
              debugPrint(
                'Image $i exceeds size limit (${fileSize / 1024 / 1024}MB > 5MB)',
              );
              throw ValidationException(
                'Image $i is too large. Maximum size is 5MB',
              );
            }

            final sanitizedFileName =
                'feedback_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
              final storage = _storageInstance;
              if (storage == null) {
                throw NetworkException('Firebase not available');
              }
              final ref = storage.ref().child('feedback/$userId/$sanitizedFileName');

            // Upload with error handling
            await ref.putFile(imageFile).catchError((error) {
              LoggerService.error('Failed to upload image $i: $error');
              throw StorageException('Failed to upload image: $error');
            });

            final url = await ref.getDownloadURL();
            imageUrls.add(url);
          } catch (e) {
            LoggerService.error('Error uploading image $i', error: e);
            // Continue with other images even if one fails
          }
        }
      }

      // Get device info
      final deviceInfoMap = deviceInfo ?? {};
      deviceInfoMap.addAll({
        'platform': io.Platform.operatingSystem,
        'platformVersion': io.Platform.operatingSystemVersion,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Save feedback to Firestore
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      await firestore.collection('feedback').add({
        'userId': userId,
        'userEmail': userEmail ?? user?.email ?? 'anonymous',
        'type': type,
        'category': category ?? 'general',
        'message': sanitizedMessage,
        'images': imageUrls,
        'deviceInfo': deviceInfoMap,
        'status': 'new',
        'priority': _getPriority(type, message),
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
        'resolved': false,
      }).catchError((error) {
        LoggerService.error('Failed to save feedback to Firestore: $error');
        throw StorageException('Failed to submit feedback: $error');
      });

      LoggerService.info('Feedback submitted successfully');
    } catch (e) {
      LoggerService.error('Error submitting feedback', error: e);
      rethrow;
    }
  }

  /// Get priority based on type and message content
  String _getPriority(String type, String message) {
    final lowerMessage = message.toLowerCase();

    if (type == 'error' ||
        lowerMessage.contains('crash') ||
        lowerMessage.contains('broken')) {
      return 'high';
    } else if (type == 'bug' || lowerMessage.contains('not working')) {
      return 'medium';
    }
    return 'low';
  }

  /// Get troubleshooting suggestion (rule-based AI)
  Future<String> getTroubleshootingSuggestion(String issue) async {
    try {
      final lowerIssue = issue.toLowerCase();

      // Crash/Close issues
      if (lowerIssue.contains('crash') ||
          lowerIssue.contains('close') ||
          lowerIssue.contains('force close') ||
          lowerIssue.contains('quit')) {
        return 'Try restarting the app. If the issue persists, try:\n'
            '1. Force close the app completely\n'
            '2. Restart your device\n'
            '3. Check for app updates\n'
            '4. Clear app cache in Settings';
      }

      // Login/Auth issues
      if (lowerIssue.contains('login') ||
          lowerIssue.contains('sign in') ||
          lowerIssue.contains('password') ||
          lowerIssue.contains('authentication')) {
        return 'For login issues:\n'
            '1. Check your internet connection\n'
            '2. Verify your email and password are correct\n'
            '3. Try resetting your password\n'
            '4. Make sure you\'re using the correct account\n'
            '5. Check if your account is still active';
      }

      // Game/Play issues
      if (lowerIssue.contains('game') ||
          lowerIssue.contains('play') ||
          lowerIssue.contains('round') ||
          lowerIssue.contains('tile')) {
        return 'For game issues:\n'
            '1. Make sure you have an active token (free tier) or subscription\n'
            '2. Check your internet connection\n'
            '3. Try restarting the game\n'
            '4. Verify you have enough lives (3 to start)\n'
            '5. Check if the game mode is available for your tier';
      }

      // Video/Background issues
      if (lowerIssue.contains('video') ||
          lowerIssue.contains('background') ||
          lowerIssue.contains('animation')) {
        return 'For video/background issues:\n'
            '1. Videos may take a moment to load - wait a few seconds\n'
            '2. Check your internet connection\n'
            '3. Try restarting the app\n'
            '4. Make sure you have sufficient storage space\n'
            '5. Check if videos are enabled in settings';
      }

      // Sound/Audio issues
      if (lowerIssue.contains('sound') ||
          lowerIssue.contains('audio') ||
          lowerIssue.contains('volume') ||
          lowerIssue.contains('mute')) {
        return 'For sound issues:\n'
            '1. Check your device volume\n'
            '2. Make sure Do Not Disturb is off\n'
            '3. Check app sound settings\n'
            '4. Try restarting the app\n'
            '5. Check if your device is not in silent mode';
      }

      // Performance issues
      if (lowerIssue.contains('slow') ||
          lowerIssue.contains('lag') ||
          lowerIssue.contains('freeze') ||
          lowerIssue.contains('performance')) {
        return 'For performance issues:\n'
            '1. Close other apps to free up memory\n'
            '2. Restart your device\n'
            '3. Check available storage space\n'
            '4. Make sure your device software is up to date\n'
            '5. Try clearing app cache';
      }

      // Subscription/Payment issues
      if (lowerIssue.contains('subscription') ||
          lowerIssue.contains('payment') ||
          lowerIssue.contains('premium') ||
          lowerIssue.contains('purchase')) {
        return 'For subscription issues:\n'
            '1. Check your subscription status in Settings\n'
            '2. Verify payment was successful\n'
            '3. Try restoring purchases\n'
            '4. Contact support with your receipt\n'
            '5. Check if subscription expired';
      }

      // Network/Connection issues
      if (lowerIssue.contains('network') ||
          lowerIssue.contains('connection') ||
          lowerIssue.contains('internet') ||
          lowerIssue.contains('offline')) {
        return 'For connection issues:\n'
            '1. Check your Wi-Fi or cellular data\n'
            '2. Try turning airplane mode on and off\n'
            '3. Restart your router (if on Wi-Fi)\n'
            '4. Check if other apps can connect\n'
            '5. Try switching between Wi-Fi and cellular';
      }

      // Default response
      return 'Thank you for reporting this issue! Our team will review your feedback and get back to you. '
          'In the meantime, try:\n'
          '1. Restarting the app\n'
          '2. Checking for updates\n'
          '3. Ensuring you have a stable internet connection\n'
          '4. Reviewing the Help Center for similar issues';
    } catch (e) {
      LoggerService.error('Error getting troubleshooting suggestion', error: e);
      return 'Our support team will review your issue and respond soon. Thank you for your patience!';
    }
  }

  /// Get user's feedback history
  Future<List<Map<String, dynamic>>> getUserFeedbackHistory() async {
    try {
      final user = FirebaseHelper.getCurrentUser();
      if (user == null) return [];

      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final snapshot = await firestore
          .collection('feedback')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      LoggerService.error('Error getting feedback history', error: e);
      return [];
    }
  }
}
