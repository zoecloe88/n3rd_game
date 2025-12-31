import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/models/daily_challenge.dart';
import 'package:n3rd_game/services/challenge/challenge_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Firestore implementation of ChallengeRepository
class FirestoreChallengeRepository implements ChallengeRepository {

  FirestoreChallengeRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  bool get isAvailable {
    // Check if Firebase is available OR if we have a firestore instance (for testing)
    try {
      Firebase.app();
      return true;
    } catch (e) {
      // If Firebase.app() fails, we still have a firestore instance (non-nullable)
      return true;
    }
  }

  @override
  Future<List<DailyChallenge>> loadChallenges(String userId) async {
    // Don't throw if firestore instance exists (for testing with fake_cloud_firestore)
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
          .collection('user_challenges')
          .doc(userId)
          .get()
          .timeout(_timeout);

      if (!doc.exists || doc.data() == null) {
        return [];
      }

      final data = doc.data()!;
      final challengesList = data['challenges'] as List?;

      if (challengesList == null) {
        return [];
      }

      return challengesList
          .map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      LoggerService.error('Firestore load timeout for challenges');
      throw NetworkException(
        'Request timed out while loading challenges',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied loading challenges',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Challenge service is currently unavailable',
          errorCode: ErrorCode.networkServerError,
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      LoggerService.error('Firestore error loading challenges', error: e);
      throw StorageException(
        'Failed to load challenges: ${e.message}',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error loading challenges',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to load challenges',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> saveChallenges({
    required String userId,
    required List<DailyChallenge> challenges,
  }) async {
    if (!isAvailable) {
      throw NetworkException(
        'Firebase is not available',
        errorCode: ErrorCode.networkNoConnection,
        recoverySuggestion:
            'Please check your internet connection and try again.',
      );
    }

    try {
      await _firestore.collection('user_challenges').doc(userId).set(
        {
          'challenges': challenges.map((c) => c.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error('Firestore save timeout for challenges');
      throw NetworkException(
        'Request timed out while saving challenges',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied saving challenges',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Challenge service is currently unavailable',
          errorCode: ErrorCode.networkServerError,
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      LoggerService.error('Firestore error saving challenges', error: e);
      throw StorageException(
        'Failed to save challenges: ${e.message}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error saving challenges',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to save challenges',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> updateChallenge({
    required String userId,
    required DailyChallenge challenge,
  }) async {
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
          .collection('user_challenges')
          .doc(userId)
          .get()
          .timeout(_timeout);

      if (!doc.exists || doc.data() == null) {
        throw StorageException(
          'User challenges document not found',
          errorCode: ErrorCode.storageReadFailed,
          recoverySuggestion: 'Please try again later.',
        );
      }

      final data = doc.data()!;
      final challengesList = (data['challenges'] as List?)
              ?.map((c) => DailyChallenge.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];

      final index = challengesList.indexWhere((c) => c.id == challenge.id);
      if (index == -1) {
        challengesList.add(challenge);
      } else {
        challengesList[index] = challenge;
      }

      await _firestore.collection('user_challenges').doc(userId).set(
        {
          'challenges': challengesList.map((c) => c.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(_timeout);
    } on TimeoutException {
      LoggerService.error('Firestore update timeout for challenge');
      throw NetworkException(
        'Request timed out while updating challenge',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied updating challenge',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Challenge service is currently unavailable',
          errorCode: ErrorCode.networkServerError,
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      LoggerService.error('Firestore error updating challenge', error: e);
      throw StorageException(
        'Failed to update challenge: ${e.message}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error updating challenge',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to update challenge',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }
}
