import 'package:flutter_test/flutter_test.dart';
import 'package:n3rd_game/services/performance_monitoring_service.dart';
import '../utils/test_helpers.dart';

void main() {
  // Initialize test binding to prevent warnings
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelpers.setupAllTestInfrastructure();
  });

  tearDownAll(() async {
    await TestHelpers.tearDownAllTestInfrastructure();
  });

  group('PerformanceMonitoringService Tests', () {
    late PerformanceMonitoringService service;

    setUp(() {
      TestHelpers.setupMockSharedPreferences();
      service = PerformanceMonitoringService();
    });

    tearDown(() {
      service.dispose();
      TestHelpers.clearMockSharedPreferences();
    });

    test('service initializes correctly', () async {
      await service.init();

      expect(service.isInitialized, isTrue);
      expect(service.isMonitoring, isTrue);
    });

    test('recordMetric adds metric to history', () async {
      await service.init();

      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test_widget',
        const Duration(milliseconds: 50),
      );

      expect(service.metrics.length, greaterThan(0));
    });

    test('metrics are limited to max history size', () async {
      await service.init();

      // Record more metrics than max history
      for (int i = 0; i < 1100; i++) {
        service.recordMetric(
          PerformanceMetricType.widgetBuild,
          'test_$i',
          const Duration(milliseconds: 10),
        );
      }

      expect(service.metrics.length, lessThanOrEqualTo(1000));
    });

    test('trackWidgetBuild measures build time', () async {
      await service.init();

      final result = service.trackWidgetBuild('TestWidget', () {
        return 'result';
      });

      expect(result, equals('result'));
      expect(service.metrics.length, greaterThan(0));
    });

    test('trackNetworkRequest measures request duration', () async {
      await service.init();

      final result = await service.trackNetworkRequest(
        'test_request',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'response';
        },
      );

      expect(result, equals('response'));
      expect(service.metrics.length, greaterThan(0));
    });

    test('trackFirestoreQuery measures query duration', () async {
      await service.init();

      final result = await service.trackFirestoreQuery(
        'test_query',
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      expect(result, equals('data'));
      expect(service.metrics.length, greaterThan(0));
    });

    test('getMetricsByType returns filtered metrics', () async {
      await service.init();

      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'widget1',
        const Duration(milliseconds: 10),
      );
      service.recordMetric(
        PerformanceMetricType.networkRequest,
        'request1',
        const Duration(milliseconds: 20),
      );

      final widgetMetrics =
          service.getMetricsByType(PerformanceMetricType.widgetBuild);
      expect(widgetMetrics.length, greaterThan(0));
      expect(
        widgetMetrics.every((m) => m.type == PerformanceMetricType.widgetBuild),
        isTrue,
      );
    });

    test('clearMetrics removes all metrics', () async {
      await service.init();

      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test',
        const Duration(milliseconds: 10),
      );

      service.clearMetrics();

      expect(service.metrics.length, equals(0));
    });

    test('stopMonitoring pauses metric recording', () async {
      await service.init();

      service.stopMonitoring();

      expect(service.isMonitoring, isFalse);

      // Metrics should not be recorded when monitoring is stopped
      final initialCount = service.metrics.length;
      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test',
        const Duration(milliseconds: 10),
      );

      expect(service.metrics.length, equals(initialCount));
    });

    test('resumeMonitoring resumes metric recording', () async {
      await service.init();

      service.stopMonitoring();
      service.resumeMonitoring();

      expect(service.isMonitoring, isTrue);

      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test',
        const Duration(milliseconds: 10),
      );

      expect(service.metrics.length, greaterThan(0));
    });

    test('getAverageDuration calculates correct average', () async {
      await service.init();

      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test1',
        const Duration(milliseconds: 10),
      );
      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test2',
        const Duration(milliseconds: 20),
      );
      service.recordMetric(
        PerformanceMetricType.widgetBuild,
        'test3',
        const Duration(milliseconds: 30),
      );

      final average =
          service.getAverageDuration(PerformanceMetricType.widgetBuild);
      expect(average, isNotNull);
      expect(average!.inMilliseconds, equals(20));
    });
  });
}
