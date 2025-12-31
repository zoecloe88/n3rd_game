import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Chat message model
class ChatMessage {
  final String id;
  final String userId;
  final String displayName;
  final String message;
  final DateTime timestamp;
  final bool isModerated;
  final bool isDeleted;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.message,
    required this.timestamp,
    this.isModerated = false,
    this.isDeleted = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] as String,
      displayName: data['displayName'] as String? ?? 'Unknown',
      message: data['message'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isModerated: data['isModerated'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'message': message,
        'timestamp': Timestamp.fromDate(timestamp),
        'isModerated': isModerated,
        'isDeleted': isDeleted,
      };
}

/// Service for managing chat messages in public lobbies
class ChatService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      return null;
    }
  }

  /// Send a chat message to a lobby
  Future<void> sendMessage({
    required String lobbyId,
    required String message,
  }) async {
    final firestore = _firestore;
    final auth = _auth;
    final user = auth?.currentUser;

    if (firestore == null || user == null) {
      throw AuthenticationException('User must be logged in to send messages');
    }

    // Moderate message content
    final moderatedMessage = _moderateMessage(message);
    final isModerated = moderatedMessage != message;

    try {
      // Get user display name
      final userProfile = await firestore
          .collection('user_profiles')
          .doc(user.uid)
          .get();
      final displayName = userProfile.data()?['displayName'] as String? ??
          user.email?.split('@').first ??
          'User';

      // Rate limiting: Check if user sent too many messages recently
      final recentMessages = await firestore
          .collection('public_lobbies')
          .doc(lobbyId)
          .collection('chat_messages')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp',
              isGreaterThan: Timestamp.fromDate(
                DateTime.now().subtract(const Duration(seconds: 10)),
              ),)
          .count()
          .get();

      if (recentMessages.count! >= 5) {
        throw ValidationException(
          'You are sending messages too quickly. Please wait a moment.',
        );
      }

      // Add message to Firestore
      await firestore
          .collection('public_lobbies')
          .doc(lobbyId)
          .collection('chat_messages')
          .add({
        'userId': user.uid,
        'displayName': displayName,
        'message': moderatedMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'isModerated': isModerated,
        'isDeleted': false,
      });

      // Update last activity timestamp
      await firestore.collection('public_lobbies').doc(lobbyId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Error sending chat message', error: e);
      rethrow;
    }
  }

  /// Get stream of chat messages for a lobby
  Stream<List<ChatMessage>> getMessages(String lobbyId, {int limit = 50}) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('public_lobbies')
        .doc(lobbyId)
        .collection('chat_messages')
        .where('isDeleted', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  /// Moderate message content (basic profanity filter)
  String _moderateMessage(String message) {
    // Basic profanity filter - replace inappropriate words
    final profanityWords = [
      // Add profanity words here (keeping it minimal for now)
    ];

    String moderated = message;
    for (final word in profanityWords) {
      final regex = RegExp(word, caseSensitive: false);
      moderated = moderated.replaceAll(regex, '*' * word.length);
    }

    return moderated;
  }

  /// Delete a message (admin only)
  Future<void> deleteMessage({
    required String lobbyId,
    required String messageId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw NetworkException('Firestore not available');
    }

    try {
      await firestore
          .collection('public_lobbies')
          .doc(lobbyId)
          .collection('chat_messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
      });
    } catch (e) {
      LoggerService.error('Error deleting chat message', error: e);
      rethrow;
    }
  }
}
