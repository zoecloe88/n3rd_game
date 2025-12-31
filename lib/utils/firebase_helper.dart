import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Helper class for safe Firebase access
/// 
/// Provides centralized methods to check Firebase initialization
/// and safely access Firebase services without crashing the app.
class FirebaseHelper {
  /// Check if Firebase is initialized
  /// 
  /// Returns true if Firebase is initialized, false otherwise.
  /// This method never throws - it catches all exceptions.
  static bool isInitialized() {
    try {
      Firebase.app();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Safely get current Firebase user
  /// 
  /// Returns the current Firebase user if Firebase is initialized
  /// and a user is logged in. Returns null otherwise.
  /// This method never throws - it catches all exceptions.
  static User? getCurrentUser() {
    try {
      if (isInitialized()) {
        return FirebaseAuth.instance.currentUser;
      }
    } catch (e) {
      // Firebase not initialized or error
    }
    return null;
  }
}
