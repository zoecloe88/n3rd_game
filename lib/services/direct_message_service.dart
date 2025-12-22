import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/direct_message.dart';
import 'package:n3rd_game/services/edition_access_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

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

  void setEditionAccessService(EditionAccessService? service) {
    _editionAccessService = service;
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
      debugPrint('Error checking premium access: $e');
      return false;
    }
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
      debugPrint('Direct messaging requires premium access');
      return;
    }

    _conversationsSubscription?.cancel();
    _conversationsSubscription = firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .listen((snapshot) {
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
              debugPrint('Error parsing conversation: $e');
            }
          }
          notifyListeners();
        });
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

    _messagesSubscription?.cancel();
    _messages.clear();

    _messagesSubscription = firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots()
        .listen((snapshot) {
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
              debugPrint('Error parsing message: $e');
            }
          }
          notifyListeners();

          // Mark messages as read
          _markMessagesAsRead(conversationId);
        });
  }

  /// Ensure conversation exists
  Future<void> _ensureConversationExists(String otherUserId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    final conversationId = _getConversationId(userId, otherUserId);
    final conversationRef = firestore
        .collection('conversations')
        .doc(conversationId);

    final conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) {
      final currentUser = FirebaseAuth.instance.currentUser;
      await conversationRef.set({
        'participants': [userId, otherUserId],
        'user1DisplayName': currentUser?.email?.split('@').first,
        'user2DisplayName':
            null, // Will be updated when other user sends message
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCount_$userId': 0,
        'unreadCount_$otherUserId': 0,
      });
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

    final conversationId = _getConversationId(userId, otherUserId);
    await _ensureConversationExists(otherUserId);

    final currentUser = FirebaseAuth.instance.currentUser;
    final messageData = {
      'fromUserId': userId,
      'toUserId': otherUserId,
      'fromDisplayName': currentUser?.email?.split('@').first,
      'message': message.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    // Add message to conversation
    await firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(messageData);

    // Update conversation
    await firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': {...messageData, 'timestamp': Timestamp.now()},
      'lastActivity': FieldValue.serverTimestamp(),
      'unreadCount_$otherUserId': FieldValue.increment(1),
    });
  }

  /// Mark messages as read
  Future<void> _markMessagesAsRead(String conversationId) async {
    final userId = _userId;
    final firestore = _firestore;
    if (userId == null || firestore == null) return;

    final unreadMessages = await firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count
    batch.update(firestore.collection('conversations').doc(conversationId), {
      'unreadCount_$userId': 0,
    });

    await batch.commit();
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
