/// Interface for analytics service
/// Provides contract for analytics operations
abstract class AnalyticsServiceInterface {
  /// Initialize analytics service
  Future<void> init();

  /// Log event
  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters});

  /// Log screen view
  Future<void> logScreenView(String screenName);

  /// Log user property
  Future<void> setUserProperty(String name, String? value);

  /// Log conversion funnel event
  Future<void> logConversionFunnel(String step,
      {Map<String, dynamic>? metadata,});

  /// Dispose resources
  void dispose();
}













