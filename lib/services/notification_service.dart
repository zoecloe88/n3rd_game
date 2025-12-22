import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        debugPrint('FCM Token: $_fcmToken');

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
        _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp
            .listen(_handleMessageTap);

        // Check if app was opened from notification
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }

        _initialized = true;
        notifyListeners();
      } else {
        debugPrint('Notification permission denied');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      await firestore.collection('user_tokens').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      debugPrint('Foreground message: ${message.notification?.title}');
      // Show local notification or in-app notification
      // For now, just log it
    } catch (e) {
      debugPrint('Error handling foreground message: $e');
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    try {
      debugPrint('Message tapped: ${message.data}');
      // Handle navigation based on message data
      // This will be handled by the app's navigation system
    } catch (e) {
      debugPrint('Error handling message tap: $e');
    }
  }

  // Send notification to user (for multiplayer invites, etc.)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final tokenDoc = await firestore
          .collection('user_tokens')
          .doc(userId)
          .get();

      if (!tokenDoc.exists) {
        debugPrint('User token not found for $userId');
        return;
      }

      final token = tokenDoc.data()?['fcmToken'] as String?;
      if (token == null) {
        debugPrint('FCM token is null for $userId');
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
      debugPrint('Error sending notification: $e');
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
  debugPrint('Background message: ${message.messageId}');
}
