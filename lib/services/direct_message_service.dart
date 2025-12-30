import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/direct_message.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/firestore_error_handler.dart';

class DirectMessageService extends ChangeNotifier {
  FirebaseFirestore? get _firestore {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  String? get _userId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      return null;
    }
  }

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  final List<DirectMessage> _messages = [];
  final List<Conversation> _conversations = [];
  String? _currentConversationId;

  List<DirectMessage> get messages => List.unmodifiable(_messages);
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  String? get currentConversationId => _currentConversationId;

  EditionAccessService? _editionAccessService;
  SubscriptionService? _subscriptionService;
  final Map<String, int> _dailyMessageCounts =
      {}; // Track messages per day per user
  final Map<String, DateTime> _lastMessageTimes =
      {}; // Track last message time for rate limiting

  void setEditionAccessService(EditionAccessService? service) {
    _editionAccessService = service;
  }

  void setSubscriptionService(SubscriptionService? service) {
    _subscriptionService = service;
  }

  /// Check if user has premium access for direct messaging
  Future<bool> hasPremiumAccess() async {
    try {
      if (_editionAccessService == null) {
        final editionAccessService = EditionAccessService();
        await editionAccessService.init();
        return editionAccessService.hasAllAccess;
      }
      return _editionAccessService!.hasAllAccess;
    } catch (e) {
      LoggerService.error('Error checking premium access', error: e);
      return false;
    }
  }

  /// Get message limit for current tier
  int _getMessageLimit() {
    if (_subscriptionService == null) {
      return 10; // Default to free tier limit
    }

    if (_subscriptionService!.isFree) {
      return 10; // 10 messages/day
    } else if (_subscriptionService!.isBasic) {
      return 100; // 100 messages/day
    } else {
      return -1; // Unlimited for Premium and Family/Friends
    }
  }

  /// Get character limit per message for current tier
  int _getCharacterLimit() {
    if (_subscriptionService == null) {
      return 500; // Default limit
    }

    if (_subscriptionService!.isFree) {
      return 200; // 200 characters per message
    } else if (_subscriptionService!.isBasic) {
      return 1000; // 1000 characters per message
    } else {
      return 5000; // 5000 characters for Premium and Family/Friends
    }
  }

  /// Check if user can send message based on tier constraints
  Future<Map<String, dynamic>> canSendMessage() async {
    final userId = _userId;
    if (userId == null) {
      return {
        'canSend': false,
        'reason': 'User not authenticated',
        'remaining': 0,
      };
    }

    final limit = _getMessageLimit();
    if (limit == -1) {
      // Unlimited
      return {
        'canSend': true,
        'reason': null,
        'remaining': -1, // Unlimited
      };
    }

    // Check daily message count
    final today = DateTime.now().toIso8601String().split('T')[0];
    final messageCount = _dailyMessageCounts[today] ?? 0;

    if (messageCount >= limit) {
      return {
        'canSend': false,
        'reason': 'Daily message limit reached. Upgrade to send more messages.',
        'remaining': 0,
      };
    }

    return {
      'canSend': true,
      'reason': null,
      'remaining': limit - messageCount,
    };
  }

  /// Check rate limiting for message sending (prevents spam)
  bool _checkRateLimit(String otherUserId) {
    final now = DateTime.now();
    final lastMessageTime = _lastMessageTimes[otherUserId];

    if (lastMessageTime != null) {
      final timeSinceLastMessage = now.difference(lastMessageTime);
      // Rate limit: 1 message per 2 seconds
      if (timeSinceLastMessage.inSeconds < 2) {
        return false;
      }
    }

    _lastMessageTimes[otherUserId] = now;
    return true;
  }

  /// Get or create conversation ID between two users
  String _getConversationId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Start listening to conversations
  Future<void> loadConversations() async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    // Check premium access
    final hasPremium = await hasPremiumAccess();
    if (!hasPremium) {
      LoggerService.debug('Direct messaging requires premium access');
      return;
    }

    unawaited((_conversationsSubscription?.cancel() ?? Future<void>.value()) as Future<dynamic>,);
    _conversationsSubscription = firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _conversations.clear();
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final participants = List<String>.from(
              data['participants'] as List,
            );

            // CRITICAL: Check participants array has exactly 2 elements before accessing indices
            // Direct messages require exactly 2 participants (userId1 and userId2)
            if (participants.length != 2) {
              debugPrint(
                'Invalid conversation: participants array must have exactly 2 elements, got ${participants.length}',
              );
              continue; // Skip this conversation
            }

            _conversations.add(
              Conversation(
                id: doc.id,
                userId1: participants[0],
                userId2: participants[1],
                user1DisplayName: data['user1DisplayName'] as String?,
                user2DisplayName: data['user2DisplayName'] as String?,
                lastMessage: data['lastMessage'] != null
                    ? DirectMessage.fromJson(
                        data['lastMessage'] as Map<String, dynamic>,
                      )
                    : null,
                unreadCount: data['unreadCount_$userId'] as int? ?? 0,
                lastActivity: data['lastActivity'] != null
                    ? (data['lastActivity'] as Timestamp).toDate()
                    : null,
              ),
            );
          } catch (e) {
            LoggerService.error('Error parsing conversation', error: e);
          }
        }
        notifyListeners();
      },
      onError: (error) {
        // CRITICAL: Handle Firestore permission errors gracefully
        if (error is FirebaseException && error.code == 'permission-denied') {
          LoggerService.error(
            'DirectMessageService: Permission denied loading conversations. User may not be authenticated or lacks premium access.',
            error: error,
            reason: 'Firestore permission-denied error',
            fatal: false,
          );
          // Clear conversations and notify listeners
          _conversations.clear();
          notifyListeners();
        } else {
          LoggerService.error(
            'DirectMessageService: Error loading conversations',
            error: error,
            reason: 'Firestore stream error',
            fatal: false,
          );
        }
      },
    );
  }

  /// Start listening to messages in a conversation
  Future<void> loadMessages(String otherUserId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    // Check premium access
    final hasPremium = await hasPremiumAccess();
    if (!hasPremium) {
      throw ValidationException('Direct messaging requires premium access');
    }

    final conversationId = _getConversationId(userId, otherUserId);
    _currentConversationId = conversationId;

    // Ensure conversation exists
    await _ensureConversationExists(otherUserId);

    unawaited((_messagesSubscription?.cancel() ?? Future<void>.value()) as Future<dynamic>,);
    _messages.clear();

    _messagesSubscription = firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .listen(
      (snapshot) {
        _messages.clear();
        for (final doc in snapshot.docs) {
          try {
            _messages.add(
              DirectMessage.fromJson({
                'id': doc.id,
                'conversationId': conversationId,
                ...doc.data(),
              }),
            );
          } catch (e) {
            LoggerService.error('Error parsing message', error: e);
          }
        }
        notifyListeners();

        // Mark messages as read after loading
        _markMessagesAsRead(conversationId);
      },
      onError: (error) {
        // CRITICAL: Handle Firestore permission errors gracefully
        if (error is FirebaseException && error.code == 'permission-denied') {
          LoggerService.error(
            'DirectMessageService: Permission denied loading messages. User may not be authenticated or lacks premium access.',
            error: error,
            reason: 'Firestore permission-denied error',
            fatal: false,
          );
          // Clear messages and notify listeners
          _messages.clear();
          notifyListeners();
        } else {
          LoggerService.error(
            'DirectMessageService: Error loading messages',
            error: error,
            reason: 'Firestore stream error',
            fatal: false,
          );
        }
      },
    );
  }

  /// Ensure conversation exists
  Future<void> _ensureConversationExists(String otherUserId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    final conversationId = _getConversationId(userId, otherUserId);
    final conversationRef =
        firestore.collection('conversations').doc(conversationId);

    final conversationDoc =
        await FirestoreErrorHandler.handleFirestoreDocumentOperation(
      () => conversationRef.get(),
      operationName: 'get_conversation',
    );
    if (!conversationDoc.exists) {
      final currentUser = FirebaseAuth.instance.currentUser;
      await FirestoreErrorHandler.handleFirestoreDocumentOperation(
        () => conversationRef.set({
          'participants': [userId, otherUserId],
          'user1DisplayName': currentUser?.email?.contains('@') == true
              ? currentUser!.email!.split('@').first
              : currentUser?.email,
          'user2DisplayName':
              null, // Will be updated when other user sends message
          'lastActivity': FieldValue.serverTimestamp(),
          'unreadCount_$userId': 0,
          'unreadCount_$otherUserId': 0,
        }),
        operationName: 'create_conversation',
      );
    }
  }

  /// Send direct message
  Future<void> sendMessage(String otherUserId, String message) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Check premium access
    final hasPremium = await hasPremiumAccess();
    if (!hasPremium) {
      throw ValidationException('Direct messaging requires premium access');
    }

    if (message.trim().isEmpty) {
      throw ValidationException('Message cannot be empty');
    }

    // Check tier-based message limits
    final canSendResult = await canSendMessage();
    if (!(canSendResult['canSend'] as bool)) {
      final reason = canSendResult['reason'] as String?;
      if (reason != null) {
        throw ValidationException(reason);
      }
    }

    // Check character limit
    final charLimit = _getCharacterLimit();
    if (message.length > charLimit) {
      throw ValidationException(
        'Message exceeds character limit ($charLimit characters). Please shorten your message.',
      );
    }

    // Check rate limiting (prevent spam)
    if (!_checkRateLimit(otherUserId)) {
      throw ValidationException(
        'Please wait a moment before sending another message.',
      );
    }

    final conversationId = _getConversationId(userId, otherUserId);
    await _ensureConversationExists(otherUserId);

    final currentUser = FirebaseAuth.instance.currentUser;
    final messageData = {
      'fromUserId': userId,
      'toUserId': otherUserId,
      'fromDisplayName': currentUser?.email?.contains('@') == true
          ? currentUser!.email!.split('@').first
          : currentUser?.email,
      'message': message.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    // Add message to conversation
    await FirestoreErrorHandler.handleFirestoreDocumentOperation(
      () => firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData),
      operationName: 'send_message',
    );

    // Update conversation
    await FirestoreErrorHandler.handleFirestoreDocumentOperation(
      () => firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': {...messageData, 'timestamp': Timestamp.now()},
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCount_$otherUserId': FieldValue.increment(1),
      }),
      operationName: 'update_conversation',
    );

    // Update daily message count for tier-based limits
    final limit = _getMessageLimit();
    if (limit != -1) {
      // Only track if there's a limit (not unlimited)
      final today = DateTime.now().toIso8601String().split('T')[0];
      _dailyMessageCounts[today] = (_dailyMessageCounts[today] ?? 0) + 1;
    }
  }

  /// Mark messages as read
  Future<void> _markMessagesAsRead(String conversationId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    final unreadMessages = await FirestoreErrorHandler.handleFirestoreQuery(
      () => firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('toUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get(),
      operationName: 'get_unread_messages',
    );

    if (unreadMessages.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count
    batch.update(firestore.collection('conversations').doc(conversationId), {
      'unreadCount_$userId': 0,
    });

    await FirestoreErrorHandler.handleFirestoreDocumentOperation(
      () => batch.commit(),
      operationName: 'mark_messages_read',
    );
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    final conversationId = _currentConversationId;
    if (conversationId == null) {
      throw ValidationException('No active conversation');
    }

    // Get message to verify ownership
    final messageDoc = await firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) {
      throw ValidationException('Message not found');
    }

    final messageData = messageDoc.data();
    if (messageData?['fromUserId'] != userId) {
      throw ValidationException('You can only delete your own messages');
    }

    // Delete message
    await FirestoreErrorHandler.handleFirestoreDocumentOperation(
      () => firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete(),
      operationName: 'delete_message',
    );
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) {
      throw AuthenticationException('User not authenticated');
    }

    // Delete all messages in conversation
    final messagesSnapshot = await firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();

    final batch = firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete conversation
    batch.delete(firestore.collection('conversations').doc(conversationId));

    await batch.commit();
  }

  /// Set typing indicator
  Future<void> setTypingIndicator(String otherUserId, bool isTyping) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    final conversationId = _getConversationId(userId, otherUserId);
    await firestore.collection('conversations').doc(conversationId).update(
      {'typing_$userId': isTyping ? FieldValue.serverTimestamp() : null},
    );
  }

  /// Stop listening to messages
  void stopListening() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _messages.clear();
    _currentConversationId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    super.dispose();
  }
}