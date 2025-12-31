import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/firebase_helper.dart';

/// Service for handling push notifications
class NotificationService extends ChangeNotifier {
  FirebaseMessaging? _messaging;
  String? _fcmToken;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _initialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      Firebase.app();
      _messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging!.getToken();
        LoggerService.debug('FCM Token: $_fcmToken');

        // Save token to Firestore for current user
        await _saveTokenToFirestore(_fcmToken);

        // Listen for token refresh
        _tokenSubscription = _messaging!.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveTokenToFirestore(newToken);
          notifyListeners();
        });

        // CRITICAL: Store foreground message subscription for proper cleanup
        _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
          _handleForegroundMessage,
        );

        // CRITICAL: Store message opened subscription for proper cleanup
        _messageOpenedSubscription =
            FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // Check if app was opened from notification
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }

        _initialized = true;
        notifyListeners();
      } else {
        LoggerService.debug('Notification permission denied');
      }
    } catch (e) {
      LoggerService.error('Error initializing notifications', error: e);
    }
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseHelper.getCurrentUser();
    if (user == null) return;

    // CRITICAL: Check Firebase is initialized before accessing Firestore
    if (!FirebaseHelper.isInitialized()) {
      LoggerService.debug('Firebase not initialized, skipping FCM token save');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('user_tokens').doc(user.uid).set(
        {
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      LoggerService.error('Failed to save FCM token to Firestore', error: e);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      LoggerService.debug('Foreground message: ${message.notification?.title}');
      // Show local notification or in-app notification
      // For now, just log it
    } catch (e) {
      LoggerService.error('Error handling foreground message', error: e);
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    try {
      LoggerService.debug('Message tapped: ${message.data}');
      // Handle navigation based on message data
      // Check for room invitation type
      if (message.data['type'] == 'room_invitation') {
        final roomCode = message.data['roomCode'] as String?;
        final deepLink = message.data['deepLink'] as String?;
        if (roomCode != null) {
          // Navigate to multiplayer lobby with room code
          // This will be handled by the app's navigation system
          // The deep link handler in main.dart will process this
          LoggerService.debug('Room invitation tapped: $roomCode');
          // Store room code for navigation
          _pendingRoomCode = roomCode;
        } else if (deepLink != null) {
          // Parse deep link and extract room code
          try {
            final uri = Uri.parse(deepLink);
            final roomCode = uri.queryParameters['room'];
            if (roomCode != null) {
              _pendingRoomCode = roomCode;
              LoggerService.debug('Room invitation tapped via deep link: $roomCode');
            }
          } catch (e) {
            LoggerService.error('Error parsing deep link', error: e);
          }
        }
      }
      // Other navigation will be handled by the app's navigation system
    } catch (e) {
      LoggerService.error('Error handling message tap', error: e);
    }
  }

  String? _pendingRoomCode;
  String? get pendingRoomCode => _pendingRoomCode;
  void clearPendingRoomCode() => _pendingRoomCode = null;

  // Send notification to user (for multiplayer invites, etc.)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // CRITICAL: Check Firebase is initialized before accessing Firestore
    if (!FirebaseHelper.isInitialized()) {
      LoggerService.debug('Firebase not initialized, skipping notification send');
      return;
    }
    try {
      final firestore = FirebaseFirestore.instance;
      final tokenDoc =
          await firestore.collection('user_tokens').doc(userId).get();

      if (!tokenDoc.exists) {
        LoggerService.debug('User token not found for $userId');
        return;
      }

      final token = tokenDoc.data()?['fcmToken'] as String?;
      if (token == null) {
        LoggerService.debug('FCM token is null for $userId');
        return;
      }

      // Send via Cloud Functions or FCM Admin SDK
      // For now, we'll create a notification document that Cloud Functions can process
      await firestore.collection('notifications').add({
        'userId': userId,
        'fcmToken': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      LoggerService.error('Error sending notification', error: e);
    }
  }

  /// Send room invitation notification to a friend
  Future<void> sendRoomInvitationNotification(
    String friendUserId,
    String roomId,
    String inviterName,
    String roomCode,
  ) async {
    // CRITICAL: Check Firebase is initialized before accessing Firestore
    if (!FirebaseHelper.isInitialized()) {
      LoggerService.debug('Firebase not initialized, skipping room invitation notification');
      return;
    }
    try {
      final firestore = FirebaseFirestore.instance;
      final tokenDoc =
          await firestore.collection('user_tokens').doc(friendUserId).get();

      if (!tokenDoc.exists) {
        LoggerService.debug('User token not found for $friendUserId');
        return;
      }

      final token = tokenDoc.data()?['fcmToken'] as String?;
      if (token == null) {
        LoggerService.debug('FCM token is null for $friendUserId');
        return;
      }

      final deepLink = 'n3rdgame://multiplayer/join?room=$roomCode';

      // Create notification document that Cloud Functions can process
      await firestore.collection('notifications').add({
        'userId': friendUserId,
        'fcmToken': token,
        'title': '$inviterName invited you to play!',
        'body': 'Join their N3RD Trivia game. Room Code: $roomCode',
        'data': {
          'type': 'room_invitation',
          'roomId': roomId,
          'roomCode': roomCode,
          'inviterName': inviterName,
          'deepLink': deepLink,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      LoggerService.error('Error sending room invitation notification', error: e);
    }
  }

  /// Enable push notifications
  /// Requests permission and initializes notification service
  Future<bool> enableNotifications() async {
    try {
      if (!_initialized) {
        await init();
      }
      return _initialized;
    } catch (e) {
      LoggerService.error('Error enabling notifications', error: e);
      return false;
    }
  }

  /// Disable push notifications
  /// Unsubscribes from token refresh and message streams
  Future<void> disableNotifications() async {
    try {
      // Cancel all subscriptions
      _tokenSubscription?.cancel();
      _tokenSubscription = null;
      _foregroundMessageSubscription?.cancel();
      _foregroundMessageSubscription = null;
      _messageOpenedSubscription?.cancel();
      _messageOpenedSubscription = null;

      // Delete FCM token from Firestore
      final user = FirebaseHelper.getCurrentUser();
      if (user != null && FirebaseHelper.isInitialized()) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('user_tokens').doc(user.uid).delete();
        } catch (e) {
          LoggerService.debug('Failed to delete FCM token', error: e);
        }
      }

      _fcmToken = null;
      _initialized = false;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error disabling notifications', error: e);
    }
  }

  @override
  void dispose() {
    // CRITICAL: Cancel all stream subscriptions to prevent memory leaks
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = null;

    // Reset state to allow re-initialization if needed
    _initialized = false;
    _fcmToken = null;
    _messaging = null;

    super.dispose();
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  LoggerService.debug('Background message: ${message.messageId}');
}
