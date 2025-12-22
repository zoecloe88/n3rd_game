import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Service for exporting user data
class DataExportService {
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

  /// Export all user data to JSON file
  Future<String?> exportUserData() async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw AuthenticationException('User not authenticated');
      }

      final exportData = <String, dynamic>{
        'exportDate': DateTime.now().toIso8601String(),
        'userId': userId,
        'userEmail': FirebaseAuth.instance.currentUser?.email,
      };

      final firestore = _firestore;

      // Export stats
      try {
        if (firestore != null) {
          final statsDoc = await firestore
              .collection('user_stats')
              .doc(userId)
              .get();
          if (statsDoc.exists) {
            exportData['stats'] = statsDoc.data();
          }
        }
      } catch (e) {
        debugPrint('Failed to export stats: $e');
      }

      // Export analytics
      try {
        if (firestore != null) {
          final analyticsDoc = await firestore
              .collection('user_analytics')
              .doc(userId)
              .get();
          if (analyticsDoc.exists) {
            exportData['analytics'] = analyticsDoc.data();
          }
        }
      } catch (e) {
        debugPrint('Failed to export analytics: $e');
      }

      // Export learning data
      try {
        if (firestore != null) {
          final learningDoc = await firestore
              .collection('user_learning')
              .doc(userId)
              .get();
          if (learningDoc.exists) {
            exportData['learning'] = learningDoc.data();
          }
        }
      } catch (e) {
        debugPrint('Failed to export learning data: $e');
      }

      // Export game history (if exists)
      try {
        if (firestore != null) {
          final gameHistorySnapshot = await firestore
              .collection('game_history')
              .where('userId', isEqualTo: userId)
              .limit(100)
              .get();

          exportData['gameHistory'] = gameHistorySnapshot.docs
              .map((doc) => doc.data())
              .toList();
        }
      } catch (e) {
        debugPrint('Failed to export game history: $e');
      }

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/n3rd_trivia_data_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);

      return file.path;
    } catch (e) {
      debugPrint('Failed to export user data: $e');
      rethrow;
    }
  }

  /// Share exported data
  Future<void> shareExportedData() async {
    try {
      final filePath = await exportUserData();
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await Share.shareXFiles([
            XFile(filePath),
          ], text: 'My N3RD Trivia Data Export',);
        }
      }
    } catch (e) {
      debugPrint('Failed to share exported data: $e');
      rethrow;
    }
  }

  /// Export data as formatted text (readable format)
  Future<String?> exportUserDataAsText() async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw AuthenticationException('User not authenticated');
      }

      final buffer = StringBuffer();
      buffer.writeln('N3RD Trivia - User Data Export');
      buffer.writeln('Export Date: ${DateTime.now().toIso8601String()}');
      buffer.writeln('User ID: $userId');
      buffer.writeln(
        'Email: ${FirebaseAuth.instance.currentUser?.email ?? 'N/A'}',
      );
      buffer.writeln('');
      buffer.writeln('=' * 50);
      buffer.writeln('');

      final firestore = _firestore;

      // Export stats
      if (firestore != null) {
        try {
          final statsDoc = await firestore
              .collection('user_stats')
              .doc(userId)
              .get();
          if (statsDoc.exists) {
            final data = statsDoc.data();
            buffer.writeln('STATISTICS');
            buffer.writeln('-' * 50);
            if (data != null) {
              buffer.writeln('Total Games: ${data['totalGamesPlayed'] ?? 0}');
              buffer.writeln(
                'Correct Answers: ${data['totalCorrectAnswers'] ?? 0}',
              );
              buffer.writeln(
                'Wrong Answers: ${data['totalWrongAnswers'] ?? 0}',
              );
              buffer.writeln('Highest Score: ${data['highestScore'] ?? 0}');
            }
            buffer.writeln('');
          }
        } catch (e) {
          debugPrint('Failed to export stats: $e');
        }
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/n3rd_trivia_data_export_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(buffer.toString());

      return file.path;
    } catch (e) {
      debugPrint('Failed to export user data as text: $e');
      rethrow;
    }
  }
}
