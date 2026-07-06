import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';

FlutterUmamiConfig makeConfig({
  String websiteId = 'test-id',
  String endpoint = 'https://example.com',
  String hostname = 'test.com',
  UmamiQueueConfig? queueConfig,
  UmamiLogger? logger,
  bool enabled = true,
  String? userId,
  Duration? httpTimeout,
  String? instanceName,
  String? ipAddress,
  String? firstReferrer,
  String? language,
}) {
  return FlutterUmamiConfig(
    websiteId: websiteId,
    endpoint: endpoint,
    hostname: hostname,
    queueConfig: queueConfig ?? const InMemoryUmamiQueueConfig(),
    logger: logger ?? const UmamiLogger(),
    enabled: enabled,
    userId: userId,
    httpTimeout: httpTimeout ?? const Duration(seconds: 5),
    instanceName: instanceName,
    ipAddress: ipAddress,
    firstReferrer: firstReferrer,
    language: language,
  );
}

({UmamiLogger logger, List<String> logs}) makeLogger({
  UmamiLogLevel minLevel = UmamiLogLevel.debug,
}) {
  final logs = <String>[];
  final logger = UmamiLogger(
    customLogger: (level, msg) => logs.add(msg),
    minLevel: minLevel,
  );
  return (logger: logger, logs: logs);
}

void main() {
  group('FlutterUmamiConfig', () {
    test('FlutterUmamiConfig stores required fields verbatim', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      expect(config.websiteId, 'test-id');
      expect(config.endpoint, 'https://example.com');
      expect(config.hostname, 'test.com');
      expect(config.enabled, true);
    });

    test('copyWith overrides specified fields', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final updated = config.copyWith(enabled: false, userId: 'user-1');
      expect(updated.enabled, false);
      expect(updated.userId, 'user-1');
      expect(updated.websiteId, 'test-id');
    });

    test('copyWith with no args returns identical config', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final copy = config.copyWith();
      expect(copy.websiteId, config.websiteId);
      expect(copy.endpoint, config.endpoint);
      expect(copy.hostname, config.hostname);
      expect(copy.enabled, config.enabled);
    });

    test('copyWith with overrides preserves untouched fields', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final updated = config.copyWith(endpoint: 'https://other.com');
      expect(updated.endpoint, 'https://other.com');
      expect(updated.websiteId, 'test-id');
      expect(updated.hostname, 'test.com');
    });

    test('merge ignores non-string values for typed fields', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final merged = config.merge({'websiteId': 123, 'hostname': 'safe.com'});
      expect(merged.websiteId, 'test-id');
      expect(merged.hostname, 'safe.com');
    });

    test('merge with null returns same config', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final merged = config.merge(null);
      expect(identical(merged, config), true);
    });

    test('merge with empty map returns same config', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final merged = config.merge({});
      expect(identical(merged, config), true);
    });

    test('merge overrides string fields', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      final merged = config.merge({
        'websiteId': 'new-id',
        'language': 'fr',
        'userId': 'user-x',
      });
      expect(merged.websiteId, 'new-id');
      expect(merged.language, 'fr');
      expect(merged.userId, 'user-x');
      expect(merged.hostname, 'test.com');
    });

    test('default queueConfig is inMemory', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      expect(config.queueConfig, isA<InMemoryUmamiQueueConfig>());
      expect(config.queueConfig.maxSize, 500);
    });

    test('default httpTimeout is 5 seconds', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      expect(config.httpTimeout, const Duration(seconds: 5));
    });

    test('default instanceName is null', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
      );
      expect(config.instanceName, isNull);
    });

    test('instanceName is preserved in copyWith', () {
      const config = FlutterUmamiConfig(
        websiteId: 'test-id',
        endpoint: 'https://example.com',
        hostname: 'test.com',
        instanceName: 'my-instance',
      );
      final copy = config.copyWith();
      expect(copy.instanceName, 'my-instance');
    });
  });

  group('UmamiLogger', () {
    test('respects minLevel', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.info,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.debug('should not appear');
      logger.info('should appear');
      expect(logs.length, 1);
      expect(logs.first, contains('should appear'));
    });

    test('customLogger receives messages', () {
      final l = makeLogger();
      l.logger.info('hello');
      expect(l.logs.length, 1);
    });

    test('customLogger receives correct level', () {
      UmamiLogLevel? receivedLevel;
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.verbose,
        customLogger: (level, msg) => receivedLevel = level,
      );
      logger.error('test');
      expect(receivedLevel, UmamiLogLevel.error);
    });

    test('default minLevel is warning', () {
      const logger = UmamiLogger();
      expect(logger.minLevel, UmamiLogLevel.warning);
    });

    test('verbose method logs at verbose level', () {
      final l = makeLogger(minLevel: UmamiLogLevel.verbose);
      l.logger.verbose('verbose msg');
      expect(l.logs.length, 1);
    });

    test('warning level filters out info', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.warning,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.info('info msg');
      expect(logs, isEmpty);
    });

    test('none level filters everything', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.none,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.error('error msg');
      expect(logs, isEmpty);
    });

    test('formatted message includes [Umami] prefix', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.info,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.info('Test Message');
      expect(logs.first, contains('[Umami]'));
    });

    test('formatted message includes level tag', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.info,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.info('Test Message');
      expect(logs.first, contains('[INFO]'));
    });

    test('formatted message includes original message', () {
      final logs = <String>[];
      final logger = UmamiLogger(
        minLevel: UmamiLogLevel.info,
        customLogger: (level, msg) => logs.add(msg),
      );
      logger.info('Test Message');
      expect(logs.first, contains('Test Message'));
    });
  });

  group('UmamiQueueConfig', () {
    test('disabled config has maxSize 0', () {
      const config = UmamiQueueConfig.disabled();
      expect(config.maxSize, 0);
    });

    test('inMemory config has configurable maxSize', () {
      const config = UmamiQueueConfig.inMemory(maxSize: 100);
      expect(config.maxSize, 100);
    });

    test('persisted config has default 48h TTL', () {
      const config = UmamiQueueConfig.persisted(maxSize: 200);
      expect(config.maxSize, 200);
      expect(
        (config as PersistedUmamiQueueConfig).eventTtl,
        const Duration(hours: 48),
      );
    });
  });

  group('FlutterUmamiAnalytics instance API', () {
    late FlutterUmamiAnalytics analytics;
    late _MockCollector collector;

    setUp(() {
      collector = _MockCollector();
      analytics = FlutterUmamiAnalytics(
        config: makeConfig(),
        collector: collector,
      );
    });

    tearDown(() async {
      await analytics.dispose();
    });

    test('constructor creates instance with default values', () {
      expect(analytics.config.websiteId, 'test-id');
      expect(analytics.apiClient, isNull);
      expect(analytics.config.instanceName, isNull);
    });

    test('constructor accepts instanceName in config', () {
      final custom = FlutterUmamiAnalytics(
        config: makeConfig(instanceName: 'my-instance'),
        collector: _MockCollector(),
      );
      addTearDown(custom.dispose);
      expect(custom.config.instanceName, 'my-instance');
    });

    test('multiple instances can coexist', () {
      final a = FlutterUmamiAnalytics(
        config: makeConfig(
            websiteId: 'site-1', endpoint: 'https://a.com', hostname: 'a.com'),
        collector: _MockCollector(),
      );
      final b = FlutterUmamiAnalytics(
        config: makeConfig(
            websiteId: 'site-2', endpoint: 'https://b.com', hostname: 'b.com'),
        collector: _MockCollector(),
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(a.config.websiteId, 'site-1');
      expect(b.config.websiteId, 'site-2');
      expect(identical(a, b), false);
    });

    test('dispose does not throw and is idempotent', () async {
      await analytics.dispose();
      await analytics.dispose();
      expect(collector.disposeCalls, 1);
    });

    test('trackPageView forwards to collector', () async {
      final result = await analytics.trackPageView(url: '/home');
      expect(result, true);
      expect(collector.events, ['pv:/home']);
    });

    test('trackEvent forwards to collector', () async {
      final result = await analytics.trackEvent(name: 'signup');
      expect(result, true);
      expect(collector.events, ['event:signup']);
    });

    test('identify forwards to collector', () async {
      final result = await analytics.identify(properties: {'role': 'admin'});
      expect(result, true);
      expect(collector.events, ['identify']);
    });

    test('disabled config short-circuits tracking', () async {
      final disabled = FlutterUmamiAnalytics(
        config: makeConfig(enabled: false),
        collector: _MockCollector(),
      );
      addTearDown(disabled.dispose);
      final result = await disabled.trackPageView(url: '/x');
      expect(result, false);
      expect(disabled.config.enabled, false);
    });
  });

  group('DeviceInfoData', () {
    test('DeviceInfoData stores all fields', () {
      const data = DeviceInfoData(
        screenResolution: '1080x1920',
        locale: 'es_MX',
        platform: 'android',
      );
      expect(data.screenResolution, '1080x1920');
      expect(data.locale, 'es_MX');
      expect(data.platform, 'android');
    });
  });
}

class _MockCollector implements UmamiCollector {
  final List<String> events = [];
  int flushCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> trackPageView({
    String? url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    Map<String, dynamic>? overrides,
  }) async {
    events.add('pv:$url');
    return true;
  }

  @override
  Future<bool> trackEvent({
    required String name,
    String? url,
    String? title,
    String? referrer,
    Map<String, dynamic>? data,
    String? hostname,
    String? language,
    String? screen,
    Map<String, dynamic>? overrides,
  }) async {
    events.add('event:$name');
    return true;
  }

  @override
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    Map<String, dynamic>? overrides,
  }) async {
    events.add('identify');
    return true;
  }

  @override
  Future<void> flush() async {
    flushCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
