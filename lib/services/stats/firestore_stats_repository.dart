import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/stats/stats_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Firestore implementation of StatsRepository
class FirestoreStatsRepository implements StatsRepository {

  FirestoreStatsRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  bool get isAvailable {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int?> getHighestScore(String userId) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        errorCode: ErrorCode.networkNoConnection,
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      final doc = await _firestore
          .collection('user_stats')
          .doc(userId)
          .get()
          .timeout(_timeout);

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      return data['highestScore'] as int?;
    } on TimeoutException {
      LoggerService.error(
        'Firestore get highest score timeout',
        error: TimeoutException('Timeout'),
      );
      throw NetworkException(
        'Request timed out while fetching score',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      LoggerService.error(
        'Firestore error getting highest score',
        error: e,
      );
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied getting score',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      throw StorageException(
        'Failed to get score: ${e.message}',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error(
        'Unexpected error getting highest score',
        error: e,
        stack: stack,
      );
      throw StorageException(
        'Failed to get score',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, int>> getFriendScores(List<String> userIds) async {
    if (!isAvailable) {
      return {};
    }

    if (userIds.isEmpty) {
      return {};
    }

    try {
      // Batch fetch scores for multiple users
      final scores = <String, int>{};

      // Firestore doesn't support IN queries with more than 10 items efficiently
      // So we'll fetch in batches of 10
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();

        // Use whereIn for batches
        final snapshot = await _firestore
            .collection('user_stats')
            .where(FieldPath.documentId, whereIn: batch)
            .get()
            .timeout(_timeout);

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final score = data['highestScore'] as int?;
          if (score != null) {
            scores[doc.id] = score;
          }
        }
      }

      return scores;
    } on TimeoutException {
      LoggerService.error(
        'Firestore get friend scores timeout',
        error: TimeoutException('Timeout'),
      );
      return {}; // Return empty map on timeout
    } catch (e) {
      LoggerService.error(
        'Error getting friend scores',
        error: e,
      );
      return {}; // Return empty map on error
    }
  }
}













