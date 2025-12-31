import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/models/trivia_item.dart';
import 'package:n3rd_game/services/trivia/trivia_repository.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Firestore implementation of TriviaRepository
class FirestoreTriviaRepository implements TriviaRepository {

  FirestoreTriviaRepository(this._firestore);
  final FirebaseFirestore _firestore;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  Future<String> saveCustomTrivia({
    required String userId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
    String? difficulty,
    bool isPublic = false,
  }) async {
    try {
      final triviaItem = {
        'category': category,
        'question': question,
        'words': words,
        'correctAnswers': correctAnswers,
        'difficulty': difficulty ?? 'medium',
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'isCustom': true,
        'isPublic': isPublic,
      };

      final docRef = await _firestore
          .collection('custom_trivia')
          .add(triviaItem)
          .timeout(_timeout);

      return docRef.id;
    } on TimeoutException {
      LoggerService.error('Firestore save timeout for custom trivia');
      throw NetworkException(
        'Request timed out while saving trivia',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied saving trivia',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      } else if (e.code == 'unavailable') {
        throw NetworkException(
          'Trivia service is currently unavailable',
          errorCode: ErrorCode.networkServerError,
          recoverySuggestion:
              'Please check your connection and try again later.',
        );
      }
      LoggerService.error('Firestore error saving custom trivia', error: e);
      throw StorageException(
        'Failed to save trivia: ${e.message}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error saving custom trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to save trivia',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<void> saveLocalTrivia({
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    // Local storage is handled by LocalTriviaRepository
    throw UnimplementedError('Use LocalTriviaRepository for local saves');
  }

  @override
  Future<void> shareTrivia({
    required String fromUserId,
    required String toUserId,
    required String category,
    required String question,
    required List<String> words,
    required List<String> correctAnswers,
  }) async {
    try {
      final triviaData = {
        'category': category,
        'question': question,
        'words': words,
        'correctAnswers': correctAnswers,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'sentAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('shared_trivia')
          .add(triviaData)
          .timeout(_timeout);
    } on TimeoutException {
      LoggerService.error('Firestore share timeout');
      throw NetworkException(
        'Request timed out while sharing trivia',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied sharing trivia',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      LoggerService.error('Firestore error sharing trivia', error: e);
      throw StorageException(
        'Failed to share trivia: ${e.message}',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error sharing trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to share trivia',
        errorCode: ErrorCode.storageWriteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<List<TriviaItem>> getCustomTrivia({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('custom_trivia')
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit.clamp(1, 100))
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TriviaItem(
          category:
              data['category'] as String? ?? data['question'] as String? ?? '',
          words: List<String>.from(data['words'] as List? ?? []),
          correctAnswers:
              List<String>.from(data['correctAnswers'] as List? ?? []),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } on TimeoutException {
      LoggerService.error('Firestore get timeout for custom trivia');
      throw NetworkException(
        'Request timed out while loading trivia',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied accessing trivia',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      LoggerService.error('Firestore error getting custom trivia', error: e);
      throw StorageException(
        'Failed to load trivia: ${e.message}',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error getting custom trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to load trivia',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<List<TriviaItem>> getLocalTrivia() async {
    throw UnimplementedError('Use LocalTriviaRepository for local trivia');
  }

  @override
  Future<List<TriviaItem>> getSharedTrivia({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('shared_trivia')
          .where('toUserId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .limit(limit.clamp(1, 100))
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TriviaItem(
          category:
              data['category'] as String? ?? data['question'] as String? ?? '',
          words: List<String>.from(data['words'] as List? ?? []),
          correctAnswers:
              List<String>.from(data['correctAnswers'] as List? ?? []),
          createdAt: (data['sentAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } on TimeoutException {
      LoggerService.error('Firestore get timeout for shared trivia');
      throw NetworkException(
        'Request timed out while loading shared trivia',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied accessing shared trivia',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      LoggerService.error('Firestore error getting shared trivia', error: e);
      throw StorageException(
        'Failed to load shared trivia: ${e.message}',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error getting shared trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to load shared trivia',
        errorCode: ErrorCode.storageReadFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }

  @override
  Future<bool> deleteCustomTrivia({
    required String userId,
    required String triviaId,
  }) async {
    try {
      await _firestore
          .collection('custom_trivia')
          .doc(triviaId)
          .delete()
          .timeout(_timeout);
      return true;
    } on TimeoutException {
      LoggerService.error('Firestore delete timeout');
      throw NetworkException(
        'Request timed out while deleting trivia',
        errorCode: ErrorCode.networkTimeout,
        recoverySuggestion: 'Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PermissionException(
          'Permission denied deleting trivia',
          errorCode: ErrorCode.systemPermissionDenied,
          recoverySuggestion:
              'Please check your account permissions and try again.',
        );
      }
      LoggerService.error('Firestore error deleting trivia', error: e);
      throw StorageException(
        'Failed to delete trivia: ${e.message}',
        errorCode: ErrorCode.storageDeleteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    } catch (e, stack) {
      LoggerService.error('Unexpected error deleting trivia',
          error: e, stack: stack,);
      throw StorageException(
        'Failed to delete trivia',
        errorCode: ErrorCode.storageDeleteFailed,
        recoverySuggestion: 'Please try again later.',
      );
    }
  }
}
















