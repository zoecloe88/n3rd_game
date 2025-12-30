import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:n3rd_game/exceptions/app_exceptions.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/services/secure_storage_service.dart';
import 'package:n3rd_game/services/rate_limiter_service.dart';
import 'package:n3rd_game/utils/device_fingerprint.dart';
import 'package:n3rd_game/config/app_config.dart';

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

  // Session management
  DateTime? _lastSessionActivity;
  Timer? _sessionTimeoutTimer;
  bool _sessionExpired = false;

  // Biometric authentication
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  // Account lockout
  final RateLimiterService _rateLimiter = RateLimiterService();

  // MFA infrastructure (preparation)
  bool _mfaEnabled = false;

  bool get isAuthenticated => _isAuthenticated && !_sessionExpired;
  String? get userEmail => _userEmail ?? _firebaseUser?.email;
  User? get currentUser => _firebaseUser;
  bool get isBiometricAvailable => _biometricAvailable;
  bool get isBiometricEnabled => _biometricEnabled;
  bool get isMfaEnabled => _mfaEnabled;
  bool get isSessionExpired => _sessionExpired;

  // Get or initialize SharedPreferences
  // CRITICAL: Handle SharedPreferences initialization failures to prevent crashes
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    try {
      _prefs = await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      // SharedPreferences initialization failed - log and rethrow
      // This prevents silent failures that could cause data loss
      LoggerService.error(
        'AuthService: Failed to initialize SharedPreferences',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );
      rethrow; // Re-throw to let caller handle the error appropriately
    }
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

  // Session management helpers
  Future<void> _loadSessionState() async {
    try {
      final prefs = await _getPrefs();
      final lastActivityMillis = prefs.getInt('last_session_activity');
      if (lastActivityMillis != null) {
        _lastSessionActivity =
            DateTime.fromMillisecondsSinceEpoch(lastActivityMillis);
      }
    } catch (e) {
      LoggerService.debug('Failed to load session state', error: e);
    }
  }

  Future<void> _saveSessionState() async {
    try {
      final prefs = await _getPrefs();
      if (_lastSessionActivity != null) {
        await prefs.setInt('last_session_activity',
            _lastSessionActivity!.millisecondsSinceEpoch,);
      }
    } catch (e) {
      LoggerService.debug('Failed to save session state', error: e);
    }
  }

  void _updateSessionActivity() {
    _lastSessionActivity = DateTime.now();
    _saveSessionState();
    _sessionExpired = false;
  }

  void _checkSessionTimeout() {
    if (_lastSessionActivity == null) {
      _sessionExpired = false;
      return;
    }

    final elapsed = DateTime.now().difference(_lastSessionActivity!);
    if (elapsed > AppConfig.sessionTimeoutDuration) {
      _sessionExpired = true;
      _isAuthenticated = false;
    }
  }

  void _startSessionTimeoutTimer() {
    _stopSessionTimeoutTimer();
    _sessionTimeoutTimer =
        Timer.periodic(AppConfig.sessionActivityCheckInterval, (_) {
      _checkSessionTimeout();
      if (_sessionExpired) {
        notifyListeners();
      }
    });
  }

  void _stopSessionTimeoutTimer() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
  }

  // Device fingerprinting for security tracking
  Future<void> _logDeviceFingerprint(String action) async {
    try {
      final fingerprint = await DeviceFingerprint.getFingerprint();
      final deviceInfo = await DeviceFingerprint.getDeviceInfo();
      LoggerService.info(
        'Auth action: $action | fingerprint: $fingerprint | device: $deviceInfo | email: ${_userEmail ?? 'none'}',
      );
    } catch (e) {
      LoggerService.debug('Failed to log device fingerprint', error: e);
    }
  }

  // Check account lockout
  Future<bool> _checkAccountLockout(String email) async {
    final action = 'login_attempt_$email';
    final isAllowed = await _rateLimiter.isAllowed(
      action,
      maxAttempts: AppConfig.maxFailedLoginAttempts,
      window: AppConfig.accountLockoutDuration,
    );

    if (!isAllowed) {
      await _logDeviceFingerprint('account_locked');
      LoggerService.warning('Account lockout triggered for email: $email');
    }

    return isAllowed;
  }

  // Record failed login attempt
  Future<void> _recordFailedLoginAttempt(String email) async {
    final action = 'login_attempt_$email';
    await _rateLimiter.isAllowed(
      action,
      maxAttempts: AppConfig.maxFailedLoginAttempts,
      window: AppConfig.accountLockoutDuration,
    );
    await _logDeviceFingerprint('login_failed');
  }

  // Reset failed login attempts on successful login
  Future<void> _resetFailedLoginAttempts(String email) async {
    final action = 'login_attempt_$email';
    await _rateLimiter.reset(action);
    await _logDeviceFingerprint('login_success');
  }

  // Biometric authentication
  Future<bool> authenticateWithBiometrics({String? reason}) async {
    if (!_biometricAvailable) {
      throw AuthenticationException(
          'Biometric authentication is not available on this device',);
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Please authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _updateSessionActivity();
        await _logDeviceFingerprint('biometric_auth_success');
      }

      return authenticated;
    } catch (e) {
      LoggerService.error('Biometric authentication failed', error: e);
      await _logDeviceFingerprint('biometric_auth_failed');
      throw AuthenticationException(
          'Biometric authentication failed: ${e.toString()}',);
    }
  }

  // Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !_biometricAvailable) {
      throw AuthenticationException(
          'Biometric authentication is not available',);
    }

    try {
      final prefs = await _getPrefs();
      await prefs.setBool('biometric_enabled', enabled);
      _biometricEnabled = enabled;
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to update biometric preference', error: e);
      throw StorageException(
          'Failed to update biometric preference: ${e.toString()}',);
    }
  }

  // MFA infrastructure (preparation)
  Future<bool> checkMfaRequired() async {
    // MFA infrastructure - ready for future implementation
    // Returns false for now, but framework is in place
    return _mfaEnabled;
  }

  // Enable/disable MFA (infrastructure preparation)
  Future<void> setMfaEnabled(bool enabled) async {
    _mfaEnabled = enabled;
    // Future: Implement MFA setup flow
    notifyListeners();
  }

  // Re-authenticate session (called when session expires)
  Future<void> reauthenticateSession() async {
    if (!_sessionExpired) {
      return;
    }

    // If biometric is enabled and available, try biometric re-auth
    if (_biometricEnabled && _biometricAvailable) {
      try {
        final authenticated = await authenticateWithBiometrics(
          reason: 'Your session has expired. Please authenticate to continue.',
        );
        if (authenticated) {
          _sessionExpired = false;
          _isAuthenticated = true;
          _updateSessionActivity();
          _startSessionTimeoutTimer();
          notifyListeners();
          return;
        }
      } catch (e) {
        LoggerService.warning('Biometric re-authentication failed', error: e);
      }
    }

    // If biometric fails or is not enabled, require full re-login
    _isAuthenticated = false;
    notifyListeners();
    throw AuthenticationException('Session expired. Please sign in again.');
  }

  // Load auth state on init
  Future<void> init() async {
    // Check biometric availability
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics;
      if (!_biometricAvailable) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        _biometricAvailable = availableBiometrics.isNotEmpty;
      }
    } catch (e) {
      LoggerService.debug('Biometric check failed', error: e);
      _biometricAvailable = false;
    }

    // Load biometric preference
    try {
      final prefs = await _getPrefs();
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    } catch (e) {
      LoggerService.debug('Failed to load biometric preference', error: e);
    }

    // Try to initialize Firebase Auth
    try {
      Firebase.app();
      _auth = FirebaseAuth.instance;
      _firebaseAvailable = true;

      // Listen to Firebase auth state changes
      _authStateSubscription = _auth!.authStateChanges().listen((user) {
        _firebaseUser = user;
        _isAuthenticated = user != null;
        _userEmail = user?.email;
        if (_isAuthenticated) {
          _updateSessionActivity();
          _startSessionTimeoutTimer();
        } else {
          _stopSessionTimeoutTimer();
        }
        notifyListeners();
      });

      // Check current Firebase user
      _firebaseUser = _auth!.currentUser;
      _isAuthenticated = _firebaseUser != null;
      _userEmail = _firebaseUser?.email;

      if (_isAuthenticated) {
        await _loadSessionState();
        _updateSessionActivity();
        _startSessionTimeoutTimer();
      }

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

    // Fallback to local storage - use secure storage for email
    try {
      final prefs = await _getPrefs();
      _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
      // Try secure storage first for email, fallback to SharedPreferences for migration
      final secureStorage = SecureStorageService();
      _userEmail =
          await secureStorage.getEmail() ?? prefs.getString('userEmail');
      // Migrate email to secure storage if found in SharedPreferences
      if (_userEmail != null && prefs.containsKey('userEmail')) {
        await secureStorage.saveEmail(_userEmail!);
        // Optionally remove from SharedPreferences after migration (keep for now for compatibility)
      }

      if (_isAuthenticated) {
        await _loadSessionState();
        _checkSessionTimeout();
        if (!_sessionExpired) {
          _updateSessionActivity();
          _startSessionTimeoutTimer();
        }
      }

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

    // Check account lockout
    final isAllowed = await _checkAccountLockout(email);
    if (!isAllowed) {
      final remainingTime = await _rateLimiter.getTimeUntilReset(
        'login_attempt_$email',
        window: AppConfig.accountLockoutDuration,
      );
      if (remainingTime != null) {
        final minutes = remainingTime.inMinutes;
        throw AuthenticationException(
          'Account locked due to too many failed attempts. Please try again in $minutes minute${minutes != 1 ? 's' : ''}.',
        );
      } else {
        throw AuthenticationException(
          'Account locked due to too many failed attempts. Please try again later.',
        );
      }
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
        _sessionExpired = false;

        // Reset failed login attempts on successful login
        await _resetFailedLoginAttempts(email.trim());

        // Update session activity
        _updateSessionActivity();
        _startSessionTimeoutTimer();

        // Log device fingerprint
        await _logDeviceFingerprint('login_success');

        notifyListeners();
        return;
      } on FirebaseAuthException catch (e, stackTrace) {
        // Record failed login attempt
        await _recordFailedLoginAttempt(email.trim());

        // Log error to Crashlytics
        unawaited(FirebaseCrashlytics.instance.recordError(e, stackTrace, fatal: false));

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
        await _recordFailedLoginAttempt(email.trim());
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
      // Use secure storage for email encryption
      final secureStorage = SecureStorageService();
      await secureStorage.saveEmail(email.trim());
      await prefs.setBool('isAuthenticated', true);
      // Keep in SharedPreferences for backward compatibility during migration
      await prefs.setString('userEmail', email.trim());
      _isAuthenticated = true;
      _userEmail = email.trim();
      _sessionExpired = false;

      // Reset failed login attempts
      await _resetFailedLoginAttempts(email.trim());

      // Update session activity
      _updateSessionActivity();
      _startSessionTimeoutTimer();

      // Log device fingerprint
      await _logDeviceFingerprint('login_success');

      notifyListeners();
    } catch (e) {
      await _recordFailedLoginAttempt(email.trim());
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
        final userCredential =
            await firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        _firebaseUser = userCredential.user;
        _isAuthenticated = _firebaseUser != null;
        _userEmail = _firebaseUser?.email;
        _sessionExpired = false;

        // Update session activity
        _updateSessionActivity();
        _startSessionTimeoutTimer();

        // Log device fingerprint
        await _logDeviceFingerprint('signup_success');

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
      // Use secure storage for email encryption
      final secureStorage = SecureStorageService();
      await secureStorage.saveEmail(email.trim());
      await prefs.setBool('isAuthenticated', true);
      // Keep in SharedPreferences for backward compatibility during migration
      await prefs.setString('userEmail', email.trim());
      _isAuthenticated = true;
      _userEmail = email.trim();
      _sessionExpired = false;

      // Update session activity
      _updateSessionActivity();
      _startSessionTimeoutTimer();

      // Log device fingerprint
      await _logDeviceFingerprint('signup_success');

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
      _sessionExpired = false;
      _lastSessionActivity = null;

      // Stop session timeout timer
      _stopSessionTimeoutTimer();

      // Clear local storage
      try {
        final prefs = await _getPrefs();
        await prefs.remove('isAuthenticated');
        await prefs.remove('userEmail');
        await prefs.remove('last_session_activity');
        // Also clear secure storage
        final secureStorage = SecureStorageService();
        await secureStorage.delete('user_email');
      } catch (e) {
        // Ignore local storage errors
      }

      // Log sign out
      await _logDeviceFingerprint('signout');

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
    _stopSessionTimeoutTimer();
    super.dispose();
  }
}