import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/logger_service.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  bool _firebaseAvailable = false;
  StreamSubscription<User?>? _authStateSubscription;

  // Lazy getter for FirebaseAuth that checks if Firebase is initialized
  FirebaseAuth? get auth {
    if (_auth != null) {
      return _auth!;
    }
    if (!_firebaseAvailable) {
      return null;
    }
    try {
      // Check if Firebase is initialized
      Firebase.app();
      _auth = FirebaseAuth.instance;
      return _auth!;
    } catch (e) {
      // Firebase not initialized
      LoggerService.debug('Firebase not initialized', error: e);
      _firebaseAvailable = false;
      return null;
    }
  }

  // Check if Firebase is available
  bool get isFirebaseAvailable => _firebaseAvailable;

  // Cache SharedPreferences instance for fallback
  SharedPreferences? _prefs;

  bool _isAuthenticated = false;
  String? _userEmail;
  User? _firebaseUser;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail ?? _firebaseUser?.email;
  User? get currentUser => _firebaseUser;

  // Get or initialize SharedPreferences
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Email validation regex pattern
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Validate email format
  bool _isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  // Validate password strength
  // Accepts optional AppLocalizations for localized error messages
  String? _validatePasswordStrength(
    String password, {
    AppLocalizations? localizations,
  }) {
    if (password.length < 8) {
      return localizations?.passwordMinLength ??
          'Password must be at least 8 characters long';
    }

    if (password.length > 128) {
      return localizations?.passwordMaxLength ??
          'Password must be less than 128 characters';
    }

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return localizations?.passwordUppercase ??
          'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return localizations?.passwordLowercase ??
          'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) {
      return localizations?.passwordNumber ??
          'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return localizations?.passwordSpecialChar ??
          'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
    }

    // Check for common weak passwords
    final commonPasswords = ['password', '12345678', 'qwerty', 'abc123'];
    if (commonPasswords.contains(password.toLowerCase())) {
      return localizations?.passwordCommonWeak ??
          'Password is too common. Please choose a stronger password';
    }

    return null; // Password is strong
  }

  // Load auth state on init
  Future<void> init() async {
    // Try to initialize Firebase Auth
    try {
      Firebase.app();
      _auth = FirebaseAuth.instance;
      _firebaseAvailable = true;

      // Listen to Firebase auth state changes
      _authStateSubscription = _auth!.authStateChanges().listen((User? user) {
        _firebaseUser = user;
        _isAuthenticated = user != null;
        _userEmail = user?.email;
        notifyListeners();
      });

      // Check current Firebase user
      _firebaseUser = _auth!.currentUser;
      _isAuthenticated = _firebaseUser != null;
      _userEmail = _firebaseUser?.email;

      notifyListeners();
      return;
    } catch (e) {
      // Firebase not available - will use local storage
      _firebaseAvailable = false;
      LoggerService.debug(
        'Firebase auth not available, using local storage fallback',
        error: e,
      );
    }

    // Fallback to local storage
    try {
      final prefs = await _getPrefs();
      _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
      _userEmail = prefs.getString('userEmail');
      notifyListeners();
    } catch (e2) {
      // Don't throw - just log and continue with default state
      LoggerService.warning('Failed to load authentication state', error: e2);
      _isAuthenticated = false;
      _userEmail = null;
      notifyListeners();
    }
  }

  // Sign in with email and password using Firebase
  Future<void> signInWithEmail(String email, String password) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      throw ValidationException('Invalid email address format');
    }

    // Validate password (for login, just check minimum length)
    // Note: Using hardcoded message for login as it's less critical than signup
    if (password.length < 8) {
      throw ValidationException('Password must be at least 8 characters');
    }

    // Try Firebase first if available
    final firebaseAuth = auth;
    if (firebaseAuth != null) {
      try {
        // Sign in with Firebase
        final userCredential = await firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        _firebaseUser = userCredential.user;
        _isAuthenticated = _firebaseUser != null;
        _userEmail = _firebaseUser?.email;

        notifyListeners();
        return;
      } on FirebaseAuthException catch (e, stackTrace) {
        // Log error to Crashlytics
        FirebaseCrashlytics.instance.recordError(e, stackTrace, fatal: false);

        // Handle Firebase auth errors
        String errorMessage = 'Authentication failed';
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password sign-in is not enabled';
            break;
          default:
            errorMessage = e.message ?? 'Authentication failed';
        }
        throw AuthenticationException(errorMessage);
      } catch (e) {
        if (e is AuthenticationException) {
          rethrow;
        }
        throw AuthenticationException('Failed to sign in: ${e.toString()}');
      }
    }

    // Firebase not available - use local storage fallback
    try {
      final prefs = await _getPrefs();
      // For local storage, we'll just store the email (no password validation)
      // This is a simple fallback for when Firebase isn't available
      await prefs.setBool('isAuthenticated', true);
      await prefs.setString('userEmail', email.trim());
      _isAuthenticated = true;
      _userEmail = email.trim();
      notifyListeners();
    } catch (e) {
      throw AuthenticationException('Failed to sign in: ${e.toString()}');
    }
  }

  // Sign up with email and password using Firebase
  Future<void> signUpWithEmail(
    String email,
    String password, {
    AppLocalizations? localizations,
  }) async {
    // Validate email format
    if (!_isValidEmail(email)) {
      throw ValidationException('Invalid email address format');
    }

    // Validate password strength with localized messages
    final passwordError = _validatePasswordStrength(
      password,
      localizations: localizations,
    );
    if (passwordError != null) {
      throw ValidationException(passwordError);
    }

    // Try Firebase first if available
    final firebaseAuth = auth;
    if (firebaseAuth != null) {
      try {
        // Create user with Firebase
        final userCredential = await firebaseAuth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

        _firebaseUser = userCredential.user;
        _isAuthenticated = _firebaseUser != null;
        _userEmail = _firebaseUser?.email;

        notifyListeners();
        return;
      } on FirebaseAuthException catch (e) {
        // Handle Firebase auth errors
        String errorMessage = 'Registration failed';
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'An account already exists with this email';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password registration is not enabled';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak';
            break;
          default:
            errorMessage = e.message ?? 'Registration failed';
        }
        throw AuthenticationException(errorMessage);
      } catch (e) {
        if (e is AuthenticationException) {
          rethrow;
        }
        throw AuthenticationException('Failed to sign up: ${e.toString()}');
      }
    }

    // Firebase not available - use local storage fallback
    try {
      final prefs = await _getPrefs();
      // For local storage, we'll just store the email (no password validation)
      // This is a simple fallback for when Firebase isn't available
      await prefs.setBool('isAuthenticated', true);
      await prefs.setString('userEmail', email.trim());
      _isAuthenticated = true;
      _userEmail = email.trim();
      notifyListeners();
    } catch (e) {
      throw AuthenticationException('Failed to sign up: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Firebase (if available)
      final firebaseAuth = auth;
      if (firebaseAuth != null) {
        try {
          await firebaseAuth.signOut();
        } catch (e) {
          // Firebase sign out failed, but continue with local cleanup
          LoggerService.warning('Firebase sign out error', error: e);
        }
      }

      // Clear local state
      _firebaseUser = null;
      _isAuthenticated = false;
      _userEmail = null;

      // Clear local storage
      try {
        final prefs = await _getPrefs();
        await prefs.remove('isAuthenticated');
        await prefs.remove('userEmail');
      } catch (e) {
        // Ignore local storage errors
      }

      notifyListeners();
    } catch (e) {
      throw StorageException('Failed to sign out: ${e.toString()}');
    }
  }

  // Update user display name
  Future<void> updateDisplayName(String displayName) async {
    if (displayName.trim().isEmpty) {
      throw ValidationException('Display name cannot be empty');
    }

    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      throw AuthenticationException(
        'Display name update is not available. Firebase is not initialized.',
      );
    }

    try {
      final user = firebaseAuth.currentUser;
      if (user == null) {
        throw AuthenticationException('No user is currently signed in');
      }

      await user.updateDisplayName(displayName.trim());
      await user.reload();
      _firebaseUser = firebaseAuth.currentUser;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(
        'Failed to update display name: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      throw AuthenticationException(
        'Failed to update display name: ${e.toString()}',
      );
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isValidEmail(email)) {
      throw ValidationException('Invalid email address format');
    }

    final firebaseAuth = auth;
    if (firebaseAuth == null) {
      throw AuthenticationException(
        'Password reset is not available. Firebase is not initialized.',
      );
    }

    try {
      await firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send password reset email';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }
      throw AuthenticationException(errorMessage);
    } catch (e) {
      throw AuthenticationException(
        'Failed to send password reset email: ${e.toString()}',
      );
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
