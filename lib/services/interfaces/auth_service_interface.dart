import 'package:firebase_auth/firebase_auth.dart';

/// Interface for authentication service
/// Provides contract for authentication operations
abstract class AuthServiceInterface {
  /// Check if user is authenticated
  bool get isAuthenticated;

  /// Get current user email
  String? get userEmail;

  /// Get current Firebase user
  User? get currentUser;

  /// Check if Firebase is available
  bool get isFirebaseAvailable;

  /// Initialize authentication service
  Future<void> init();

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword(String email, String password);

  /// Sign up with email and password
  Future<void> signUpWithEmailAndPassword(String email, String password);

  /// Sign out current user
  Future<void> signOut();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Get current user ID
  String? get userId;

  /// Dispose resources
  void dispose();
}













