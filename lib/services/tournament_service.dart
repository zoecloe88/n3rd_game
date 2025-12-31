import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/exceptions/error_codes.dart';

/// Tournament bracket type
enum TournamentBracketType {
  singleElimination,
  doubleElimination,
  roundRobin,
}

/// Tournament status
enum TournamentStatus {
  registration, // Players can register
  inProgress, // Tournament is running
  finished, // Tournament is complete
  cancelled, // Tournament was cancelled
}

/// Tournament model
class Tournament {

  Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.bracketType,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.maxParticipants,
    List<String>? participants,
    this.bracket,
    this.winnerId,
    Map<String, dynamic>? metadata,
  })  : participants = participants ?? [],
        metadata = metadata ?? {};

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        bracketType: TournamentBracketType.values.firstWhere(
          (e) => e.name == json['bracketType'],
          orElse: () => TournamentBracketType.singleElimination,
        ),
        status: TournamentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TournamentStatus.registration,
        ),
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        maxParticipants: json['maxParticipants'] as int? ?? 16,
        participants: (json['participants'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        bracket: json['bracket'] != null
            ? Map<String, dynamic>.from(json['bracket'])
            : null,
        winnerId: json['winnerId'] as String?,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'])
            : {},
      );

  factory Tournament.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tournament.fromJson({...data, 'id': doc.id});
  }
  final String id;
  final String name;
  final String description;
  final TournamentBracketType bracketType;
  final TournamentStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int maxParticipants;
  final List<String> participants; // User IDs
  final Map<String, dynamic>? bracket; // Bracket structure
  final String? winnerId;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'bracketType': bracketType.name,
        'status': status.name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'maxParticipants': maxParticipants,
        'participants': participants,
        'bracket': bracket,
        'winnerId': winnerId,
        'metadata': metadata,
      };

  bool get isFull => participants.length >= maxParticipants;
  bool get canRegister => status == TournamentStatus.registration && !isFull;
}

/// Service for managing tournaments
///
/// Foundation for tournament system with basic tournament creation,
/// registration, and bracket management. Prize/reward system to be
/// implemented in the future.
class TournamentService extends ChangeNotifier {
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
      LoggerService.debug('Firebase not available for TournamentService', error: e);
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
      LoggerService.debug('Firebase not available for TournamentService', error: e);
      return null;
    }
  }

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      LoggerService.info('TournamentService initialized');
    } catch (e) {
      LoggerService.error('Error initializing TournamentService', error: e);
      _isInitialized = false;
    }
  }

  /// Create a new tournament
  Future<Tournament> createTournament({
    required String name,
    required String description,
    required TournamentBracketType bracketType,
    required DateTime startTime,
    required int maxParticipants,
    Map<String, dynamic>? metadata,
  }) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException(
        'User must be logged in to create tournaments',
        errorCode: ErrorCode.authUserNotFound,
      );
    }

    if (name.isEmpty || description.isEmpty) {
      throw ValidationException(
        'Tournament name and description are required',
        errorCode: ErrorCode.validationEmptyField,
      );
    }

    if (maxParticipants < 2 || maxParticipants > 64) {
      throw ValidationException(
        'Tournament must have between 2 and 64 participants',
        errorCode: ErrorCode.validationOutOfRange,
      );
    }

    try {
      final tournament = Tournament(
        id: '', // Will be set by Firestore
        name: name,
        description: description,
        bracketType: bracketType,
        status: TournamentStatus.registration,
        startTime: startTime,
        maxParticipants: maxParticipants,
        participants: [user.uid], // Creator is first participant
        metadata: metadata,
      );

      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final docRef = await firestore.collection('tournaments').add(tournament.toJson());
      await docRef.update({'id': docRef.id});

      final createdTournament = tournament.copyWith(id: docRef.id);
      LoggerService.info('Created tournament: ${docRef.id}');
      return createdTournament;
    } catch (e, stack) {
      LoggerService.error('Error creating tournament', error: e, stack: stack);
      throw NetworkException(
        'Failed to create tournament: ${e.toString()}',
        errorCode: ErrorCode.networkServerError,
      );
    }
  }

  /// Register for a tournament
  Future<void> registerForTournament(String tournamentId) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      throw AuthenticationException(
        'User must be logged in to register for tournaments',
        errorCode: ErrorCode.authUserNotFound,
      );
    }

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final docRef = firestore.collection('tournaments').doc(tournamentId);

      await firestore.runTransaction<void>((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          throw ValidationException(
            'Tournament not found',
            errorCode: ErrorCode.networkNotFound,
          );
        }

        final tournament = Tournament.fromFirestore(doc);

        if (!tournament.canRegister) {
          throw ValidationException(
            'Tournament is not accepting registrations',
            errorCode: ErrorCode.validationInvalidFormat,
          );
        }

        if (tournament.participants.contains(user.uid)) {
          throw ValidationException(
            'You are already registered for this tournament',
            errorCode: ErrorCode.validationInvalidFormat,
          );
        }

        transaction.update(docRef, {
          'participants': FieldValue.arrayUnion([user.uid]),
        });
      });

      LoggerService.info(
          'User ${user.uid} registered for tournament $tournamentId',);
    } catch (e) {
      if (e is ValidationException || e is AuthenticationException) {
        rethrow;
      }
      LoggerService.error('Error registering for tournament', error: e);
      throw NetworkException(
        'Failed to register for tournament: ${e.toString()}',
        errorCode: ErrorCode.networkServerError,
      );
    }
  }

  /// Get tournament by ID
  Future<Tournament?> getTournament(String tournamentId) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final doc = await firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return null;
      }

      return Tournament.fromFirestore(doc);
    } catch (e, stack) {
      LoggerService.error('Error getting tournament', error: e, stack: stack);
      return null;
    }
  }

  /// Get upcoming tournaments
  Future<List<Tournament>> getUpcomingTournaments({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final snapshot = await firestore
          .collection('tournaments')
          .where('status', isEqualTo: TournamentStatus.registration.name)
          .where('startTime', isGreaterThan: now.toIso8601String())
          .orderBy('startTime', descending: false)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList();
    } catch (e, stack) {
      LoggerService.error('Error getting upcoming tournaments',
          error: e, stack: stack,);
      return [];
    }
  }

  /// Get active tournaments
  Future<List<Tournament>> getActiveTournaments({int limit = 10}) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final snapshot = await firestore
          .collection('tournaments')
          .where('status', isEqualTo: TournamentStatus.inProgress.name)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList();
    } catch (e, stack) {
      LoggerService.error('Error getting active tournaments',
          error: e, stack: stack,);
      return [];
    }
  }

  /// Get user's tournaments
  Future<List<Tournament>> getUserTournaments({int limit = 20}) async {
    final auth = _authInstance;
    final user = auth?.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        throw NetworkException('Firebase not available');
      }
      final snapshot = await firestore
          .collection('tournaments')
          .where('participants', arrayContains: user.uid)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      return snapshot.docs.map((doc) => Tournament.fromFirestore(doc)).toList();
    } catch (e, stack) {
      LoggerService.error('Error getting user tournaments',
          error: e, stack: stack,);
      return [];
    }
  }
}

/// Extension to add copyWith method to Tournament
extension TournamentCopyWith on Tournament {
  Tournament copyWith({
    String? id,
    String? name,
    String? description,
    TournamentBracketType? bracketType,
    TournamentStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? maxParticipants,
    List<String>? participants,
    Map<String, dynamic>? bracket,
    String? winnerId,
    Map<String, dynamic>? metadata,
  }) {
    return Tournament(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      bracketType: bracketType ?? this.bracketType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
      bracket: bracket ?? this.bracket,
      winnerId: winnerId ?? this.winnerId,
      metadata: metadata ?? this.metadata,
    );
  }
}
