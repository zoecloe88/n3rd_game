import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:n3rd_game/data/trivia_templates_consolidated.dart'
    deferred as templates;
import 'package:n3rd_game/services/logger_service.dart';
import 'package:n3rd_game/utils/unawaited_helper.dart';

/// Template initialization result
class TemplateInitResult {
  final bool initialized;
  final String? error;

  TemplateInitResult({required this.initialized, this.error});
}

/// Template initializer
class TemplateInitializer {
  /// Initialize trivia templates
  static Future<TemplateInitResult> initialize({
    required bool isFirebaseInitialized,
  }) async {
    try {
      await templates.loadLibrary();
      await Future.delayed(const Duration(milliseconds: 50));
      await templates.EditionTriviaTemplates.initialize();

      if (!templates.EditionTriviaTemplates.isInitialized) {
        final error = templates.EditionTriviaTemplates.lastValidationError ??
            'Unknown error';

        LoggerService.error(
          'CRITICAL ERROR: Template initialization failed: $error',
          error: Exception('Trivia template initialization failed: $error'),
          stack: StackTrace.current,
          fatal: false,
        );

        if (isFirebaseInitialized) {
          try {
            unawaited(
              FirebaseCrashlytics.instance.recordError(
                Exception('Trivia template initialization failed: $error'),
                StackTrace.current,
                reason:
                    'Critical app initialization failure - trivia templates not initialized',
                fatal: false,
              ),
            );
          } catch (e) {
            LoggerService.debug('Failed to log trivia init error to Crashlytics', error: e);
          }
        }

        return TemplateInitResult(initialized: false, error: error);
      }

      LoggerService.info('Trivia templates initialized successfully');
      return TemplateInitResult(initialized: true);
    } catch (e) {
      LoggerService.error(
        'CRITICAL ERROR: Failed to initialize trivia templates',
        error: e,
        stack: StackTrace.current,
        fatal: false,
      );

      if (isFirebaseInitialized) {
        try {
          unawaited(
            FirebaseCrashlytics.instance.recordError(
              e,
              StackTrace.current,
              reason:
                  'Critical app initialization failure - trivia template exception',
              fatal: false,
            ),
          );
        } catch (crashlyticsError) {
          LoggerService.debug(
            'Failed to log trivia init exception to Crashlytics',
            error: crashlyticsError,
          );
        }
      }

      return TemplateInitResult(initialized: false, error: e.toString());
    }
  }
}








