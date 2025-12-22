import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';

/// Free WebRTC-based voice chat service (replaces Agora)
/// Uses peer-to-peer connections with Firebase Firestore for signaling
class VoiceChatService extends ChangeNotifier {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCRtpSender> _audioSenders = {};

  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerEnabled = true;
  bool _isInChannel = false;
  String? _currentChannelId;
  String? _currentUserId;

  StreamSubscription<QuerySnapshot>? _signalingSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isInitialized => _isInitialized;
  bool get isMuted => _isMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool get isInChannel => _isInChannel;
  Map<String, MediaStream> get remoteStreams =>
      Map.unmodifiable(_remoteStreams);

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Get user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw AuthenticationException('User must be logged in');
      }
      _currentUserId = user.uid;

      _isInitialized = true;
      debugPrint('Voice chat service initialized (WebRTC)');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing voice chat: $e');
      _isInitialized = false;
    }
  }

  Future<void> joinChannel(String channelName) async {
    if (!_isInitialized || _currentUserId == null) {
      await init();
    }

    if (_currentUserId == null) {
      throw AuthenticationException('User must be logged in');
    }

    try {
      _currentChannelId = channelName;

      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw ValidationException(
          'Microphone permission denied. Please enable microphone access in settings.',
        );
      }

      // Create peer connection
      _peerConnection = await _createPeerConnection();

      // Get user media (microphone)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote streams
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          final remoteUserId = event.streams[0].id;
          _remoteStreams[remoteUserId] = event.streams[0];
          notifyListeners();
          debugPrint('Voice chat: Remote stream received from $remoteUserId');
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(channelName, candidate);
      };

      // Listen for connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('Voice chat: Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _isInChannel = true;
          notifyListeners();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _isInChannel = false;
          notifyListeners();
        }
      };

      // Start listening for signaling messages
      _listenForSignaling(channelName);

      // Create and send offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await _sendOffer(channelName, offer);

      _isInChannel = true;
      debugPrint('Voice chat: Joined channel $channelName');
      notifyListeners();
    } catch (e) {
      debugPrint('Error joining voice channel: $e');
      await leaveChannel();
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    try {
      _signalingSubscription?.cancel();
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

      // CRITICAL: Dispose remote streams to release audio resources
      // MediaStream objects hold audio resources that must be explicitly disposed
      for (final stream in _remoteStreams.values) {
        try {
          await stream.dispose();
        } catch (e) {
          debugPrint('Error disposing remote stream: $e');
        }
      }
      _remoteStreams.clear();
      _audioSenders.clear();

      // Clean up signaling data
      if (_currentChannelId != null && _currentUserId != null) {
        final signalingRef = _firestore
            .collection('voice_signaling')
            .doc(_currentChannelId)
            .collection('users')
            .doc(_currentUserId);
        await signalingRef.delete();
      }

      _isInChannel = false;
      _currentChannelId = null;
      debugPrint('Voice chat: Left channel');
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving voice channel: $e');
    }
  }

  Future<void> toggleMute() async {
    if (_localStream == null) return;

    try {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
      notifyListeners();
      debugPrint('Voice chat: ${_isMuted ? "Muted" : "Unmuted"}');
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    // Note: Speaker control is platform-specific and may require native code
    // For now, we'll just track the state
    _isSpeakerEnabled = !_isSpeakerEnabled;
    notifyListeners();
    debugPrint(
      'Voice chat: Speaker ${_isSpeakerEnabled ? "enabled" : "disabled"}',
    );
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    return await createPeerConnection(configuration);
  }

  Future<void> _listenForSignaling(String channelId) async {
    final signalingRef = _firestore
        .collection('voice_signaling')
        .doc(channelId)
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
        await _sendAnswer(_currentChannelId!, answer);
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
      debugPrint('Error handling signaling message: $e');
    }
  }

  Future<void> _sendOffer(String channelId, RTCSessionDescription offer) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection('voice_signaling')
        .doc(channelId)
        .collection('users')
        .doc(_currentUserId)
        .set({
          'offer': {'sdp': offer.sdp, 'type': offer.type},
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true),);
  }

  Future<void> _sendAnswer(
    String channelId,
    RTCSessionDescription answer,
  ) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection('voice_signaling')
        .doc(channelId)
        .collection('users')
        .doc(_currentUserId)
        .set({
          'answer': {'sdp': answer.sdp, 'type': answer.type},
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true),);
  }

  Future<void> _sendIceCandidate(
    String channelId,
    RTCIceCandidate candidate,
  ) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection('voice_signaling')
        .doc(channelId)
        .collection('users')
        .doc(_currentUserId)
        .set({
          'iceCandidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true),);
  }

  @override
  void dispose() {
    leaveChannel();
    _signalingSubscription?.cancel();
    super.dispose();
  }
}
