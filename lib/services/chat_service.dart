import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/models/chat_message.dart';
import 'package:n3rd_game/services/content_moderation_service.dart';
import 'package:n3rd_game/utils/input_sanitizer.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ContentModerationService _moderationService =
      ContentModerationService();

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  final List<ChatMessage> _messages = [];
  String? _currentRoomId;

  // Rate limiting: track message timestamps per user
  final Map<String, List<DateTime>> _messageTimestamps = {};
  static const int _maxMessagesPerMinute = 10;
  static const int _maxMessagesPerHour = 50;
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const Duration _hourlyLimitWindow = Duration(hours: 1);

  // Message retry queue for failed sends
  final List<_PendingMessage> _pendingMessages = [];
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get currentRoomId => _currentRoomId;

  // Start listening to chat messages for a room
  void startListening(String roomId) {
    if (_currentRoomId == roomId) return;

    // Cancel existing subscription before creating new one
    _messagesSubscription?.cancel();

    _currentRoomId = roomId;
    _messages.clear();

    _messagesSubscription = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .listen((snapshot) {
      // Store subscription for proper cleanup
      // Subscription is cancelled in stopListening() which is called from dispose()
      _messages.clear();
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final message = ChatMessage(
            id: doc.id,
            userId: data['userId'] as String,
            userName: data['userName'] as String,
            message: data['message'] as String,
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            roomId: roomId,
          );
          _messages.add(message);
        } catch (e) {
          debugPrint('Error parsing chat message: $e');
        }
      }
      // Only notify if service is still active (not disposed)
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Check rate limits for message sending
  void _checkRateLimit(String userId) {
    final now = DateTime.now();
    final userMessages = _messageTimestamps[userId] ?? [];

    // Clean old timestamps (older than 1 hour)
    final recentMessages = userMessages.where((timestamp) {
      return now.difference(timestamp) < _hourlyLimitWindow;
    }).toList();

    // Check per-minute limit
    final messagesInLastMinute = recentMessages.where((timestamp) {
      return now.difference(timestamp) < _rateLimitWindow;
    }).length;

    if (messagesInLastMinute >= _maxMessagesPerMinute) {
      throw ValidationException(
        'Rate limit exceeded. Please wait before sending another message.',
      );
    }

    // Check per-hour limit
    if (recentMessages.length >= _maxMessagesPerHour) {
      throw ValidationException(
        'Hourly message limit exceeded. Please try again later.',
      );
    }

    // Update timestamps
    recentMessages.add(now);
    _messageTimestamps[userId] = recentMessages;
  }

  /// Execute Firestore operation with timeout
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
    String operationName = 'Chat operation',
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException catch (e) {
      throw NetworkException('$operationName timed out: $e');
    }
  }

  // Send a chat message
  // CRITICAL: Includes validation, sanitization, rate limiting, timeout handling, and retry logic
  Future<void> sendMessage(String message) async {
    if (_currentRoomId == null) {
      throw ValidationException('No active room');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw AuthenticationException('User must be logged in to send messages');
    }

    // Sanitize input
    final sanitizedMessage = InputSanitizer.sanitizeText(message.trim());

    if (sanitizedMessage.isEmpty) {
      throw ValidationException('Message cannot be empty');
    }

    // Validate content (length, profanity, spam)
    final validationError = _moderationService.validateContent(
      sanitizedMessage,
      minLength: 1,
      maxLength: 500,
    );

    if (validationError != null) {
      throw ValidationException(validationError);
    }

    // Check rate limits
    _checkRateLimit(user.uid);

    // Send message with timeout handling and retry logic
    await _sendMessageWithRetry(
      sanitizedMessage: sanitizedMessage,
      userId: user.uid,
      userName: InputSanitizer.sanitizeText(
        user.displayName ??
            (user.email?.contains('@') == true
                ? user.email!.split('@').first
                : user.email) ??
            'Player',
      ),
    );
  }

  /// Send message with automatic retry on failure
  Future<void> _sendMessageWithRetry({
    required String sanitizedMessage,
    required String userId,
    required String userName,
    int attempt = 0,
  }) async {
    try {
      await _executeWithTimeout(
        () async {
          await _firestore
              .collection('game_rooms')
              .doc(_currentRoomId!)
              .collection('messages')
              .add({
            'userId': userId,
            'userName': userName,
            'message': sanitizedMessage,
            'timestamp': FieldValue.serverTimestamp(),
            'roomId': _currentRoomId,
          });
        },
        operationName: 'Send chat message',
      );

      // Success - remove any pending retries for this message
      _pendingMessages.removeWhere((p) => p.message == sanitizedMessage);
    } catch (e) {
      // Failed to send - add to retry queue if attempts remaining
      if (attempt < _maxRetries) {
        final pending = _PendingMessage(
          message: sanitizedMessage,
          userId: userId,
          userName: userName,
          attempt: attempt + 1,
          timestamp: DateTime.now(),
        );

        // Remove old pending message if exists (avoid duplicates)
        _pendingMessages.removeWhere((p) => p.message == sanitizedMessage);
        _pendingMessages.add(pending);

        // Schedule retry
        Future.delayed(_retryDelay * (attempt + 1), () {
          if (_currentRoomId != null) {
            _sendMessageWithRetry(
              sanitizedMessage: sanitizedMessage,
              userId: userId,
              userName: userName,
              attempt: attempt + 1,
            );
          }
        });
      } else {
        // Max retries exceeded - remove from queue
        _pendingMessages.removeWhere((p) => p.message == sanitizedMessage);
        rethrow; // Re-throw the error
      }
    }
  }

  /// Retry all pending messages (call when connectivity is restored)
  Future<void> retryPendingMessages() async {
    if (_pendingMessages.isEmpty || _currentRoomId == null) return;

    final messagesToRetry = List<_PendingMessage>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final pending in messagesToRetry) {
      await _sendMessageWithRetry(
        sanitizedMessage: pending.message,
        userId: pending.userId,
        userName: pending.userName,
        attempt: pending.attempt,
      );
    }
  }

  // Stop listening to messages
  void stopListening() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _messages.clear();
    _currentRoomId = null;
    // Clean up old rate limit data (older than 1 hour)
    final now = DateTime.now();
    _messageTimestamps.removeWhere((userId, timestamps) {
      final recent = timestamps.where(
        (ts) => now.difference(ts) < _hourlyLimitWindow,
      );
      if (recent.isEmpty) {
        return true; // Remove if no recent messages
      }
      _messageTimestamps[userId] = recent.toList();
      return false;
    });
    if (hasListeners) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopListening();
    _pendingMessages.clear();
    super.dispose();
  }
}

/// Internal class for tracking pending messages
class _PendingMessage {
  final String message;
  final String userId;
  final String userName;
  final int attempt;
  final DateTime timestamp;

  _PendingMessage({
    required this.message,
    required this.userId,
    required this.userName,
    required this.attempt,
    required this.timestamp,
  });
}
