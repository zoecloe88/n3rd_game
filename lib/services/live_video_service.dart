import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/services/subscription_service.dart';
import 'package:n3rd_game/services/logger_service.dart';

/// Live video service for multiplayer game sessions
/// Supports tier-based video constraints:
/// - Free: No live video
/// - Basic: 1-on-1 video calls
/// - Premium: Group video (up to 4 participants)
/// - Family/Friends: Group video (up to 8 participants)
class LiveVideoService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCRtpSender> _videoSenders = {};
  final Map<String, RTCRtpSender> _audioSenders = {};

  bool _isInitialized = false;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isInSession = false;
  String? _currentSessionId;
  String? _currentUserId;
  int _maxParticipants = 2; // Default to 1-on-1

  StreamSubscription<QuerySnapshot>? _signalingSubscription;
  FirebaseFirestore? _firestore;
  SubscriptionService? _subscriptionService;

  /// Get Firestore instance if Firebase is available
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    try {
      Firebase.app(); // Check if Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      LoggerService.debug('Firebase not available for LiveVideoService', error: e);
      return null;
    }
  }

  /// Get Auth instance if Firebase is available
  FirebaseAuth? get _authInstance {
    try {
      Firebase.app(); // Check if Firebase is initialized
      return FirebaseAuth.instance;
    } catch (e) {
      LoggerService.debug('Firebase not available for LiveVideoService', error: e);
      return null;
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isInSession => _isInSession;
  Map<String, MediaStream> get remoteStreams =>
      Map.unmodifiable(_remoteStreams);
  MediaStream? get localStream => _localStream;

  void setSubscriptionService(SubscriptionService? service) {
    _subscriptionService = service;
    _updateMaxParticipants();
  }

  /// Update max participants based on subscription tier
  void _updateMaxParticipants() {
    if (_subscriptionService == null) {
      _maxParticipants = 2; // Default to 1-on-1
      return;
    }

    if (_subscriptionService!.isFree) {
      _maxParticipants = 0; // No video for free tier
    } else if (_subscriptionService!.isBasic) {
      _maxParticipants = 2; // 1-on-1 video calls
    } else if (_subscriptionService!.isPremium) {
      _maxParticipants = 4; // Group video up to 4
    } else if (_subscriptionService!.isFamilyFriends) {
      _maxParticipants = 8; // Group video up to 8
    } else {
      _maxParticipants = 2; // Default fallback
    }
  }

  /// Check if user can use live video based on tier
  bool canUseLiveVideo() {
    if (_subscriptionService == null) {
      return false; // Can't use without subscription service
    }
    return !_subscriptionService!.isFree;
  }

  /// Get max participants for current tier
  int getMaxParticipants() {
    return _maxParticipants;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Get user ID
      final auth = _authInstance;
      final user = auth?.currentUser;
      if (user == null) {
        throw AuthenticationException('User must be logged in');
      }
      _currentUserId = user.uid;

      _updateMaxParticipants();
      _isInitialized = true;
      LoggerService.info('LiveVideoService initialized');
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error initializing LiveVideoService', error: e);
      _isInitialized = false;
    }
  }

  /// Join a video session (for multiplayer game rooms)
  Future<void> joinSession(String sessionId,
      {int currentParticipantCount = 0,}) async {
    if (!_isInitialized || _currentUserId == null) {
      await init();
    }

    if (_currentUserId == null) {
      throw AuthenticationException('User must be logged in');
    }

    // Check tier-based access
    if (!canUseLiveVideo()) {
      throw ValidationException(
        'Live video is not available for free tier. Upgrade to Basic, Premium, or Family & Friends to use live video.',
      );
    }

    // Check participant limit
    if (currentParticipantCount >= _maxParticipants) {
      throw ValidationException(
        'Video session is full. Maximum participants for your tier: $_maxParticipants',
      );
    }

    try {
      _currentSessionId = sessionId;

      // Request camera and microphone permissions
      final cameraPermission = await Permission.camera.request();
      final micPermission = await Permission.microphone.request();

      if (!cameraPermission.isGranted) {
        throw ValidationException(
          'Camera permission denied. Please enable camera access in settings.',
        );
      }

      if (!micPermission.isGranted) {
        throw ValidationException(
          'Microphone permission denied. Please enable microphone access in settings.',
        );
      }

      // Create peer connection
      _peerConnection = await _createPeerConnection();

      // Get user media (camera and microphone)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user', // Front camera
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote streams
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final remoteUserId = event.streams[0].id;
          _remoteStreams[remoteUserId] = event.streams[0];
          notifyListeners();
          LoggerService.debug(
              'Live video: Remote stream received from $remoteUserId',);
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (candidate) {
        _sendIceCandidate(sessionId, candidate);
      };

      // Listen for connection state changes
      _peerConnection!.onConnectionState = (state) {
        LoggerService.debug('Live video: Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isInSession = true;
          notifyListeners();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _isInSession = false;
          notifyListeners();
        }
      };

      // Start listening for signaling messages
      unawaited(_listenForSignaling(sessionId));

      // Create and send offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await _sendOffer(sessionId, offer);

      _isInSession = true;
      LoggerService.info('Live video: Joined session $sessionId');
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error joining video session: $e', error: e);
      await leaveSession();
      rethrow;
    }
  }

  /// Leave the video session
  Future<void> leaveSession() async {
    try {
      unawaited((_signalingSubscription?.cancel() ?? Future<void>.value()) as Future<dynamic>,);
      _signalingSubscription = null;

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Dispose remote streams
      for (final stream in _remoteStreams.values) {
        try {
          await stream.dispose();
        } catch (e) {
          LoggerService.warning('Error disposing remote stream: $e', error: e);
        }
      }
      _remoteStreams.clear();
      _videoSenders.clear();
      _audioSenders.clear();

      // Clean up signaling data
      if (_currentSessionId != null && _currentUserId != null) {
        final firestore = _firestoreInstance;
        if (firestore == null) {
          throw NetworkException('Firebase not available');
        }
        final signalingRef = firestore
            .collection('video_signaling')
            .doc(_currentSessionId)
            .collection('users')
            .doc(_currentUserId);
        await signalingRef.delete();
      }

      _isInSession = false;
      _currentSessionId = null;
      LoggerService.info('Live video: Left session');
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error leaving video session: $e', error: e);
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    try {
      _isVideoEnabled = !_isVideoEnabled;
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoEnabled;
      });
      notifyListeners();
      LoggerService.debug(
          'Live video: ${_isVideoEnabled ? "Enabled" : "Disabled"}',);
    } catch (e) {
      LoggerService.warning('Error toggling video: $e', error: e);
    }
  }

  /// Toggle audio (microphone) on/off
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    try {
      _isAudioEnabled = !_isAudioEnabled;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = _isAudioEnabled;
      });
      notifyListeners();
      LoggerService.debug(
          'Live video: Audio ${_isAudioEnabled ? "Enabled" : "Disabled"}',);
    } catch (e) {
      LoggerService.warning('Error toggling audio: $e', error: e);
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    try {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
        LoggerService.debug('Live video: Camera switched');
      }
    } catch (e) {
      LoggerService.warning('Error switching camera: $e', error: e);
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    return createPeerConnection(configuration);
  }

  Future<void> _listenForSignaling(String sessionId) async {
    final firestore = _firestoreInstance;
    if (firestore == null) {
      throw NetworkException('Firebase not available');
    }
    final signalingRef = firestore
        .collection('video_signaling')
        .doc(sessionId)
        .collection('users');

    _signalingSubscription = signalingRef.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.doc.id == _currentUserId) continue; // Skip own messages

        final data = change.doc.data() as Map<String, dynamic>;

        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          _handleSignalingMessage(data);
        }
      }
    });
  }

  Future<void> _handleSignalingMessage(Map<String, dynamic> data) async {
    try {
      if (_peerConnection == null) return;

      // Handle offer
      if (data['offer'] != null) {
        final offer = RTCSessionDescription(
          data['offer']['sdp'] as String,
          data['offer']['type'] as String,
        );
        await _peerConnection!.setRemoteDescription(offer);

        // Create and send answer
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        await _sendAnswer(_currentSessionId!, answer);
      }

      // Handle answer
      if (data['answer'] != null) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'] as String,
          data['answer']['type'] as String,
        );
        await _peerConnection!.setRemoteDescription(answer);
      }

      // Handle ICE candidate
      if (data['iceCandidate'] != null) {
        final candidate = RTCIceCandidate(
          data['iceCandidate']['candidate'] as String,
          data['iceCandidate']['sdpMid'] as String?,
          data['iceCandidate']['sdpMLineIndex'] as int?,
        );
        await _peerConnection!.addCandidate(candidate);
      }
    } catch (e) {
      LoggerService.warning('Error handling signaling message: $e', error: e);
    }
  }

  Future<void> _sendOffer(String sessionId, RTCSessionDescription offer) async {
    if (_currentUserId == null) return;

    final firestore = _firestoreInstance;
    if (firestore == null) {
      LoggerService.debug('Firebase not available, skipping cleanup');
      return;
    }
    await firestore
        .collection('video_signaling')
        .doc(sessionId)
        .collection('users')
        .doc(_currentUserId)
        .set(
      {
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _sendAnswer(
    String sessionId,
    RTCSessionDescription answer,
  ) async {
    if (_currentUserId == null) return;

    final firestore = _firestoreInstance;
    if (firestore == null) {
      LoggerService.debug('Firebase not available, skipping cleanup');
      return;
    }
    await firestore
        .collection('video_signaling')
        .doc(sessionId)
        .collection('users')
        .doc(_currentUserId)
        .set(
      {
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _sendIceCandidate(
    String sessionId,
    RTCIceCandidate candidate,
  ) async {
    if (_currentUserId == null) return;

    final firestore = _firestoreInstance;
    if (firestore == null) {
      LoggerService.debug('Firebase not available, skipping cleanup');
      return;
    }
    await firestore
        .collection('video_signaling')
        .doc(sessionId)
        .collection('users')
        .doc(_currentUserId)
        .set(
      {
        'iceCandidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'timestamp': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  void dispose() {
    leaveSession();
    _signalingSubscription?.cancel();
    super.dispose();
  }
}