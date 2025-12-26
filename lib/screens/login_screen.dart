import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:n3rd_game/services/auth_service.dart';
import 'package:n3rd_game/services/analytics_service.dart';
import 'package:n3rd_game/utils/error_handler.dart';
import 'package:n3rd_game/theme/app_colors.dart';
import 'package:n3rd_game/theme/app_spacing.dart';
import 'package:n3rd_game/theme/app_typography.dart';
import 'package:n3rd_game/widgets/video_background_widget.dart';
import 'package:n3rd_game/l10n/app_localizations.dart';
import 'package:n3rd_game/utils/navigation_helper.dart';
import 'package:flutter/gestures.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _displayNameFocusNode = FocusNode();
  bool _isLogin = true;
  bool _loading = false;
  bool _acceptTerms = false;
  bool _isTyping = false;
  TapGestureRecognizer? _termsRecognizer;
  TapGestureRecognizer? _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    // Initialize gesture recognizers after first frame to ensure context is safe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _termsRecognizer = TapGestureRecognizer()
          ..onTap = () {
            if (mounted && context.mounted) {
              NavigationHelper.safeNavigate(context, '/terms-of-service');
            }
          };
        _privacyRecognizer = TapGestureRecognizer()
          ..onTap = () {
            if (mounted && context.mounted) {
              NavigationHelper.safeNavigate(context, '/privacy-policy');
            }
          };
      }
    });
    
    // Listen for focus changes to track typing state
    _emailFocusNode.addListener(() {
      _updateTypingState();
    });
    _passwordFocusNode.addListener(() {
      _updateTypingState();
    });
    _confirmPasswordFocusNode.addListener(() {
      _updateTypingState();
    });
    _displayNameFocusNode.addListener(() {
      _updateTypingState();
    });
    
    // Listen for text changes
    _emailController.addListener(_updateTypingState);
    _passwordController.addListener(_updateTypingState);
    _confirmPasswordController.addListener(_updateTypingState);
    _displayNameController.addListener(_updateTypingState);
  }
  
  void _updateTypingState() {
    final isTyping = _emailFocusNode.hasFocus ||
        _passwordFocusNode.hasFocus ||
        _confirmPasswordFocusNode.hasFocus ||
        _displayNameFocusNode.hasFocus ||
        _emailController.text.isNotEmpty ||
        _passwordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty ||
        _displayNameController.text.isNotEmpty;
    
    if (_isTyping != isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _displayNameFocusNode.dispose();
    _termsRecognizer?.dispose();
    _privacyRecognizer?.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _loading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final analyticsService = Provider.of<AnalyticsService>(
      context,
      listen: false,
    );

    try {
      if (_isLogin) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // Log successful login
        await analyticsService.logLogin('email', success: true);
      } else {
        final localizations = AppLocalizations.of(context);
        await authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          localizations: localizations,
        );
        // Log successful signup
        await analyticsService.logSignup('email', success: true);

        // Update display name if provided
        if (_displayNameController.text.trim().isNotEmpty) {
          try {
            await authService.updateDisplayName(
              _displayNameController.text.trim(),
            );
          } catch (e) {
            // Display name update failed, but sign up succeeded - continue
            if (kDebugMode) {
              debugPrint('Display name update failed: $e');
            }
          }
        }
      }

      if (mounted) {
        // Check onboarding status - new users who sign up must complete onboarding
        if (!_isLogin) {
          // This is a signup - new users should always see onboarding
          // Don't check hasCompletedOnboarding - just redirect to onboarding
          if (mounted && context.mounted) {
            NavigationHelper.safeNavigate(
              context,
              '/onboarding',
              replace: true,
            );
            return;
          }
        }

        // Existing user or onboarding complete - show word of the day first, then proceed to title
        if (mounted && context.mounted) {
          NavigationHelper.safeNavigate(
            context,
            '/general-transition',
            replace: true,
            arguments: {'routeAfter': '/word-of-day', 'routeArgs': null},
          );
        }
      }
    } catch (e) {
      // Log auth failure
      final errorMessage = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('ValidationException: ', '')
          .replaceFirst('AuthenticationException: ', '');

      if (_isLogin) {
        await analyticsService.logLogin(
          'email',
          success: false,
          error: errorMessage,
        );
      } else {
        await analyticsService.logSignup(
          'email',
          success: false,
          error: errorMessage,
        );
      }

      // Also log error generically
      await analyticsService.logError(
        _isLogin ? 'login_failed' : 'signup_failed',
        errorMessage,
      );

      if (mounted) {
        ErrorHandler.showSnackBar(
          context,
          errorMessage,
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // Black fallback - video or static background will cover
      resizeToAvoidBottomInset: true, // Allow screen to resize when keyboard appears
      body: VideoBackgroundWidget(
        videoPath: 'assets/loginscreen.mp4',
        fit: BoxFit.cover, // CSS object-fit: cover equivalent
        alignment: Alignment.topCenter, // Characters/logos in upper portion
        loop: true,
        autoplay: true,
        // Content centered vertically to avoid top/bottom animations
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ).copyWith(
                    bottom: keyboardHeight > 0 ? keyboardHeight + AppSpacing.md : AppSpacing.xl,
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Only show title when not typing
                        if (!_isTyping) ...[
                          Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayLarge.copyWith(
                              fontSize: 32,
                              color: Colors.white, // White text directly on video background
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      // Display Name field (only for sign up)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _displayNameController,
                          focusNode: _displayNameFocusNode,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            labelStyle: AppTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            filled: true,
                            fillColor: _displayNameFocusNode.hasFocus
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colors.borderLight,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (!_isLogin) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a display name';
                              }
                              if (value.length < 2) {
                                return 'Display name must be at least 2 characters';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: _emailFocusNode.hasFocus
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.error,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: true,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: _passwordFocusNode.hasFocus
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.error,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          // For login, just check minimum length (full validation in AuthService)
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      // Confirm Password field (only for sign up)
                      if (!_isLogin) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          obscureText: true,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle: AppTypography.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            filled: true,
                            fillColor: _confirmPasswordFocusNode.hasFocus
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colors.borderLight,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: AppColors.error,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (!_isLogin) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      // Terms acceptance checkbox (only for sign up)
                      if (!_isLogin) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptTerms,
                              onChanged: (value) =>
                                  setState(() => _acceptTerms = value ?? false),
                              activeColor: colors.primaryText,
                              checkColor: Colors.white,
                            ),
                            Expanded(
                              child: RichText(
                                textAlign: TextAlign.left,
                                overflow: TextOverflow.visible,
                                softWrap: true,
                                maxLines: 3,
                                text: TextSpan(
                                  style: AppTypography.labelSmall.copyWith(
                                    color: colors.secondaryText,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: colors.primaryButton,
                                        decoration: TextDecoration.underline,
                                        decorationColor: colors.primaryButton,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: _termsRecognizer,
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: colors.primaryButton,
                                        decoration: TextDecoration.underline,
                                        decorationColor: colors.primaryButton,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      recognizer: _privacyRecognizer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 56,
                        child: Semantics(
                          label: _isLogin ? 'Sign In' : 'Sign Up',
                          button: true,
                          enabled: !_loading && (_isLogin || _acceptTerms),
                          child: ElevatedButton(
                            onPressed:
                                (_loading || (!_isLogin && !_acceptTerms))
                                    ? null
                                    : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primaryButton,
                              foregroundColor: colors.buttonText,
                              disabledBackgroundColor: Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _loading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: colors.buttonText,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'Sign In' : 'Sign Up',
                                    style: AppTypography.labelLarge,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        label: _isLogin
                            ? 'Need an account? Sign up'
                            : 'Have an account? Sign in',
                        button: true,
                        child: TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin
                                ? 'Need an account? Sign up'
                                : 'Have an account? Sign in',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}
