import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/game_room.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Filter criteria for room search
class RoomDiscoveryFilter {

  RoomDiscoveryFilter({
    this.mode,
    this.minPlayers,
    this.maxPlayers,
    this.friendsOnly,
    this.sortOrder = RoomSortOrder.newest,
  });
  final MultiplayerMode? mode;
  final int? minPlayers;
  final int? maxPlayers;
  final bool? friendsOnly;
  final RoomSortOrder sortOrder;
}

/// Sort order for room discovery
enum RoomSortOrder {
  newest,
  oldest,
  mostPlayers,
  leastPlayers,
}

/// Service for discovering and filtering game rooms
///
/// Provides enhanced room search and filtering capabilities beyond
/// the basic MultiplayerService.findAvailableRooms() method.
class RoomDiscoveryService {

  RoomDiscoveryService();
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for RoomDiscoveryService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _auth = FirebaseAuth.instance;
      return _auth;
    } catch (e) {
      LoggerService.debug('Firebase not available for RoomDiscoveryService', error: e);
      return null;
    }
  }

  /// Find available rooms with filtering
  ///
  /// [filter] - Filter criteria for room search
  /// Returns a stream of filtered room lists
  Stream<List<GameRoom>> findAvailableRooms(RoomDiscoveryFilter filter) {
    final firestore = _firestoreInstance;
    if (firestore == null) {
      return Stream.value([]); // Return empty stream if Firebase not available
    }
    try {
      Query query = firestore.collection('game_rooms');

      // Apply filters
      if (filter.mode != null) {
        query = query.where('mode', isEqualTo: filter.mode!.name);
      }

      query = query.where('status', isEqualTo: RoomStatus.waiting.name);

      // Apply sorting
      switch (filter.sortOrder) {
        case RoomSortOrder.newest:
          query = query.orderBy('createdAt', descending: true);
          break;
        case RoomSortOrder.oldest:
          query = query.orderBy('createdAt', descending: false);
          break;
        case RoomSortOrder.mostPlayers:
          // Note: Firestore doesn't support ordering by array length directly
          // We'll fetch and sort in memory
          query = query.orderBy('createdAt', descending: true);
          break;
        case RoomSortOrder.leastPlayers:
          query = query.orderBy('createdAt', descending: true);
          break;
      }

      return query.snapshots().map((snapshot) {
        final now = DateTime.now();
        final rooms = snapshot.docs
            .map((doc) {
              try {
                return GameRoom.fromFirestore(doc);
              } catch (e) {
                LoggerService.warning('Error parsing room ${doc.id}: $e');
                return null;
              }
            })
            .where((room) {
              if (room == null) return false;

              // Filter by expiration
              final expiresAt = room.expiresAt;
              if (expiresAt != null && expiresAt.isBefore(now)) {
                return false;
              }

              // Filter by room capacity
              if (room.isFull) return false;

              // Filter by min/max players
              if (filter.minPlayers != null &&
                  room.players.length < filter.minPlayers!) {
                return false;
              }
              if (filter.maxPlayers != null &&
                  room.players.length > filter.maxPlayers!) {
                return false;
              }

              // Filter by friends only
              if (filter.friendsOnly != null &&
                  room.friendsOnly != filter.friendsOnly) {
                return false;
              }

              return true;
            })
            .cast<GameRoom>()
            .toList();

        // Apply in-memory sorting for player count
        if (filter.sortOrder == RoomSortOrder.mostPlayers ||
            filter.sortOrder == RoomSortOrder.leastPlayers) {
          rooms.sort((a, b) {
            final comparison = a.players.length.compareTo(b.players.length);
            return filter.sortOrder == RoomSortOrder.mostPlayers
                ? -comparison
                : comparison;
          });
        }

        return rooms;
      });
    } catch (e, stack) {
      LoggerService.error('Error in findAvailableRooms',
          error: e, stack: stack,);
      return Stream.value([]);
    }
  }

  /// Get room recommendations based on user history
  ///
  /// Returns rooms that match the user's preferred game modes and settings
  Future<List<GameRoom>> getRoomRecommendations({
    int limit = 5,
  }) async {
    try {
      final auth = _authInstance;
      final userId = auth?.currentUser?.uid;
      if (userId == null) {
        return [];
      }

      // For now, return recently created rooms
      // Future: Analyze user's game history to recommend similar rooms
      final firestore = _firestoreInstance;
      if (firestore == null) {
        return [];
      }
      final snapshot = await firestore
          .collection('game_rooms')
          .where('status', isEqualTo: RoomStatus.waiting.name)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2) // Get more to filter
          .get();

      final now = DateTime.now();
      final rooms = snapshot.docs
          .map((doc) {
            try {
              return GameRoom.fromFirestore(doc);
            } catch (e) {
              LoggerService.warning('Error parsing room ${doc.id}: $e');
              return null;
            }
          })
          .where((room) {
            if (room == null) return false;
            if (room.isFull) return false;
            final expiresAt = room.expiresAt;
            if (expiresAt != null && expiresAt.isBefore(now)) {
              return false;
            }
            return true;
          })
          .cast<GameRoom>()
          .take(limit)
          .toList();

      return rooms;
    } catch (e, stack) {
      LoggerService.error('Error getting room recommendations',
          error: e, stack: stack,);
      return [];
    }
  }

  /// Search rooms by room code or ID
  Future<GameRoom?> searchRoomByCode(String roomCode) async {
    try {
      final sanitizedCode = roomCode.trim();
      if (sanitizedCode.isEmpty) {
        return null;
      }

      final firestore = _firestoreInstance;
      if (firestore == null) {
        return null;
      }
      final doc =
          await firestore.collection('game_rooms').doc(sanitizedCode).get();

      if (!doc.exists) {
        return null;
      }

      final room = GameRoom.fromFirestore(doc);

      // Check if room is still available
      if (room.isFull) {
        return null;
      }

      final expiresAt = room.expiresAt;
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      return room;
    } catch (e, stack) {
      LoggerService.error('Error searching room by code',
          error: e, stack: stack,);
      return null;
    }
  }
}
