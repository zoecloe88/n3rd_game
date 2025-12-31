import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Service for managing public 24/7 persistent lobbies
class PublicLobbyService {
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

  /// Create a new public persistent lobby
  Future<GameRoom> createPublicLobby({
    required MultiplayerMode mode,
    required String name,
    String? description,
    int maxPlayers = 6,
  }) async {
    final firestore = _firestore;
    final auth = _auth;
    final user = auth?.currentUser;

    if (firestore == null || user == null) {
      throw AuthenticationException('User must be logged in to create lobbies');
    }

    try {
      // Get user profile for display name
      final userProfile = await firestore
          .collection('user_profiles')
          .doc(user.uid)
          .get();
      final displayName = userProfile.data()?['displayName'] as String? ??
          user.email?.split('@').first ??
          'User';

      // Create lobby document
      final lobbyRef = firestore.collection('public_lobbies').doc();
      final now = DateTime.now();

      final lobbyData = {
        'id': lobbyRef.id,
        'hostId': user.uid,
        'mode': mode.name,
        'name': name,
        'description': description ?? '',
        'status': RoomStatus.waiting.name,
        'maxPlayers': maxPlayers,
        'currentPlayers': [user.uid],
        'isActive': true,
        'isPublic': true,
        'isPersistent': true,
        'createdAt': Timestamp.fromDate(now),
        'lastActivity': Timestamp.fromDate(now),
        'players': [
          {
            'userId': user.uid,
            'email': user.email ?? '',
            'displayName': displayName,
            'score': 0,
            'correctAnswers': 0,
            'wrongAnswers': 0,
            'isReady': false,
          }
        ],
      };

      await lobbyRef.set(lobbyData);

      // Convert to GameRoom
      return GameRoom.fromJson({
        ...lobbyData,
        'createdAt': now.toIso8601String(),
        'expiresAt': null, // Persistent lobbies don't expire
      });
    } catch (e) {
      LoggerService.error('Error creating public lobby', error: e);
      rethrow;
    }
  }

  /// Get stream of available public lobbies
  Stream<List<GameRoom>> getPublicLobbies() {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('public_lobbies')
        .where('isActive', isEqualTo: true)
        .where('isPublic', isEqualTo: true)
        .orderBy('lastActivity', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GameRoom.fromJson({
          ...data,
          'id': doc.id,
          'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
        });
      }).toList();
    });
  }

  /// Join a public lobby
  Future<GameRoom> joinPublicLobby(String lobbyId) async {
    final firestore = _firestore;
    final auth = _auth;
    final user = auth?.currentUser;

    if (firestore == null || user == null) {
      throw AuthenticationException('User must be logged in to join lobbies');
    }

    try {
      return await firestore.runTransaction((transaction) async {
        final lobbyRef = firestore.collection('public_lobbies').doc(lobbyId);
        final lobbyDoc = await transaction.get(lobbyRef);

        if (!lobbyDoc.exists) {
          throw ValidationException('Lobby not found');
        }

        final data = lobbyDoc.data()!;
        final currentPlayers = List<String>.from(data['currentPlayers'] ?? []);
        final maxPlayers = data['maxPlayers'] as int;

        if (currentPlayers.contains(user.uid)) {
          // User already in lobby
          return GameRoom.fromJson({
            ...data,
            'id': lobbyId,
            'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
          });
        }

        if (currentPlayers.length >= maxPlayers) {
          throw ValidationException('Lobby is full');
        }

        // Get user profile
        final userProfile = await firestore
            .collection('user_profiles')
            .doc(user.uid)
            .get();
        final displayName = userProfile.data()?['displayName'] as String? ??
            user.email?.split('@').first ??
            'User';

        // Add user to lobby
        currentPlayers.add(user.uid);
        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
        players.add({
          'userId': user.uid,
          'email': user.email ?? '',
          'displayName': displayName,
          'score': 0,
          'correctAnswers': 0,
          'wrongAnswers': 0,
          'isReady': false,
        });

        transaction.update(lobbyRef, {
          'currentPlayers': currentPlayers,
          'players': players,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        return GameRoom.fromJson({
          ...data,
          'id': lobbyId,
          'currentPlayers': currentPlayers,
          'players': players,
          'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
        });
      });
    } catch (e) {
      LoggerService.error('Error joining public lobby', error: e);
      rethrow;
    }
  }

  /// Leave a public lobby (lobby stays open)
  Future<void> leavePublicLobby(String lobbyId) async {
    final firestore = _firestore;
    final auth = _auth;
    final user = auth?.currentUser;

    if (firestore == null || user == null) {
      throw AuthenticationException('User must be logged in');
    }

    try {
      await firestore.runTransaction((transaction) async {
        final lobbyRef = firestore.collection('public_lobbies').doc(lobbyId);
        final lobbyDoc = await transaction.get(lobbyRef);

        if (!lobbyDoc.exists) {
          return;
        }

        final data = lobbyDoc.data()!;
        final currentPlayers = List<String>.from(data['currentPlayers'] ?? []);
        currentPlayers.remove(user.uid);

        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
        players.removeWhere((p) => p['userId'] == user.uid);

        transaction.update(lobbyRef, {
          'currentPlayers': currentPlayers,
          'players': players,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      LoggerService.error('Error leaving public lobby', error: e);
      rethrow;
    }
  }
}
