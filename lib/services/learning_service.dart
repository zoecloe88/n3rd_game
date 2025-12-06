import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:n3rd_game/models/reviewed_question.dart';

class LearningService extends ChangeNotifier {
  static const String _storageKey = 'reviewed_questions';
  List<ReviewedQuestion> _reviewedQuestions = [];
  bool _firebaseAvailable = false;

  List<ReviewedQuestion> get reviewedQuestions => _reviewedQuestions;
  List<ReviewedQuestion> get wrongAnswers =>
      _reviewedQuestions.where((q) => !q.wasCorrect).toList();
  List<ReviewedQuestion> get bookmarkedQuestions =>
      _reviewedQuestions.where((q) => q.isBookmarked).toList();

  FirebaseFirestore? get _firestore {
    if (!_firebaseAvailable) return null;
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (e) {
      _firebaseAvailable = false;
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

  Future<void> init() async {
    try {
      Firebase.app();
      _firebaseAvailable = true;

      final userId = _userId;
      if (userId != null) {
        try {
          final doc = await _firestore!
              .collection('user_learning')
              .doc(userId)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data();
            if (data == null) return;
            _reviewedQuestions =
                (data['questions'] as List?)
                    ?.map(
                      (q) =>
                          ReviewedQuestion.fromJson(q as Map<String, dynamic>),
                    )
                    .toList() ??
                [];
            notifyListeners();
            await _saveLocal();
            return;
          }
        } catch (e) {
          debugPrint('Failed to load learning data from Firestore: $e');
        }
      }
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('Firebase not available for learning: $e');
    }

    await _loadLocal();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        _reviewedQuestions =
            (data['questions'] as List?)
                ?.map(
                  (q) => ReviewedQuestion.fromJson(q as Map<String, dynamic>),
                )
                .toList() ??
            [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load learning data from local storage: $e');
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'questions': _reviewedQuestions.map((q) => q.toJson()).toList(),
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save learning data to local storage: $e');
    }
  }

  Future<void> _saveToFirestore() async {
    if (!_firebaseAvailable) return;
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore!.collection('user_learning').doc(userId).set({
        'questions': _reviewedQuestions.map((q) => q.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save learning data to Firestore: $e');
    }
  }

  /// Add a reviewed question
  Future<void> addReviewedQuestion(ReviewedQuestion question) async {
    // Remove old question with same ID if exists
    _reviewedQuestions.removeWhere((q) => q.questionId == question.questionId);

    _reviewedQuestions.add(question);

    // Keep only last 1000 questions
    if (_reviewedQuestions.length > 1000) {
      _reviewedQuestions.sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
      _reviewedQuestions = _reviewedQuestions.take(1000).toList();
    }

    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  /// Toggle bookmark status
  Future<void> toggleBookmark(String questionId) async {
    final index = _reviewedQuestions.indexWhere(
      (q) => q.questionId == questionId,
    );
    if (index != -1) {
      _reviewedQuestions[index] = _reviewedQuestions[index].copyWith(
        isBookmarked: !_reviewedQuestions[index].isBookmarked,
      );
      notifyListeners();
      await _saveLocal();
      await _saveToFirestore();
    }
  }

  /// Get questions by category
  List<ReviewedQuestion> getQuestionsByCategory(String category) {
    return _reviewedQuestions.where((q) => q.category == category).toList()
      ..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
  }

  /// Get questions by game mode
  List<ReviewedQuestion> getQuestionsByMode(String gameMode) {
    return _reviewedQuestions.where((q) => q.gameMode == gameMode).toList()
      ..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
  }

  /// Clear all reviewed questions
  Future<void> clearAll() async {
    _reviewedQuestions.clear();
    notifyListeners();
    await _saveLocal();
    await _saveToFirestore();
  }

  @override
  void dispose() {
    // LearningService uses SharedPreferences and Firestore which don't require explicit cleanup
    // but dispose for consistency with other services
    super.dispose();
  }
}
