import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';
import 'package:flutter_umami_analytics/src/infrastructure/collector/tracking_collector.dart';

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

  group('TrackingCollector overrides', () {
    late _CaptureHttpClient http;
    late TrackingCollector collector;

    setUp(() {
      http = _CaptureHttpClient();
      collector = TrackingCollector(
        config: makeConfig(
          websiteId: 'site-1',
          hostname: 'default.com',
          userId: 'user-1',
          language: 'en-US',
        ),
        httpClient: http,
        queue: _NoopQueue(),
        deviceInfo: _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1080x1920',
          locale: 'en-US',
          platform: 'test',
        )),
      );
    });

    tearDown(() async => collector.dispose());

    Map<String, dynamic> payloadOf(int index) {
      final body = http.bodies[index];
      return (body['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    }

    test('overrides map applies websiteId, hostname, language, userId',
        () async {
      await collector.trackPageView(
        url: '/x',
        overrides: {
          'websiteId': 'site-2',
          'hostname': 'over.com',
          'language': 'fr',
          'userId': 'user-2',
        },
      );
      final payload = payloadOf(0);
      expect(payload['website'], 'site-2');
      expect(payload['hostname'], 'over.com');
      expect(payload['language'], 'fr');
      expect(payload['id'], 'user-2');
    });

    test('direct params take precedence over overrides map', () async {
      await collector.trackPageView(
        url: '/x',
        hostname: 'direct.com',
        language: 'de',
        overrides: {'hostname': 'over.com', 'language': 'fr'},
      );
      final payload = payloadOf(0);
      expect(payload['hostname'], 'direct.com');
      expect(payload['language'], 'de');
    });

    test('overrides apply to trackEvent', () async {
      await collector.trackEvent(
        name: 'purchase',
        url: '/checkout',
        overrides: {'websiteId': 'site-9', 'hostname': 'shop.com'},
      );
      final payload = payloadOf(0);
      expect(payload['website'], 'site-9');
      expect(payload['hostname'], 'shop.com');
    });

    test('overrides apply to identify websiteId', () async {
      await collector.identify(
        properties: {'role': 'admin'},
        overrides: {'websiteId': 'site-id'},
      );
      final payload = payloadOf(0);
      expect(payload['website'], 'site-id');
    });

    test('non-string overrides fall back to config', () async {
      await collector.trackPageView(
        url: '/x',
        overrides: {'websiteId': 123, 'hostname': false},
      );
      final payload = payloadOf(0);
      expect(payload['website'], 'site-1');
      expect(payload['hostname'], 'default.com');
    });

    test('empty overrides preserve config defaults', () async {
      await collector.trackPageView(url: '/x', overrides: {});
      final payload = payloadOf(0);
      expect(payload['website'], 'site-1');
      expect(payload['hostname'], 'default.com');
      expect(payload['language'], 'en-US');
      expect(payload['id'], 'user-1');
    });
  });

  group('Hexagonal port injection — ownership', () {
    test(
        'TrackingCollector disposes HttpClientPort when ownsHttpClient is true',
        () async {
      final http = _CaptureHttpClient();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: http,
        queue: _NoopQueue(),
        deviceInfo: _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        )),
        ownsHttpClient: true,
      );
      await collector.dispose();
      expect(http.disposeCalls, 1);
    });

    test(
        'TrackingCollector does NOT dispose HttpClientPort when ownsHttpClient '
        'is false', () async {
      final http = _CaptureHttpClient();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: http,
        queue: _NoopQueue(),
        deviceInfo: _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        )),
        ownsHttpClient: false,
      );
      await collector.dispose();
      expect(http.disposeCalls, 0);
    });

    test(
        'TrackingCollector defaults ownsHttpClient to true (backwards '
        'compatibility)', () async {
      final http = _CaptureHttpClient();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: http,
        queue: _NoopQueue(),
        deviceInfo: _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        )),
      );
      await collector.dispose();
      expect(http.disposeCalls, 1);
    });

    test('FlutterUmamiAnalytics disposes apiClient when ownsApiClient is true',
        () async {
      final api = _CountingApiPort();
      final analytics = FlutterUmamiAnalytics(
        config: makeConfig(),
        collector: _MockCollector(),
        apiClient: api,
        ownsApiClient: true,
      );
      await analytics.dispose();
      expect(api.disposeCalls, 1);
    });

    test(
        'FlutterUmamiAnalytics does NOT dispose apiClient when ownsApiClient '
        'is false', () async {
      final api = _CountingApiPort();
      final analytics = FlutterUmamiAnalytics(
        config: makeConfig(),
        collector: _MockCollector(),
        apiClient: api,
        ownsApiClient: false,
      );
      await analytics.dispose();
      expect(api.disposeCalls, 0);
    });

    test('FlutterUmamiAnalytics defaults ownsApiClient to true', () async {
      final api = _CountingApiPort();
      final analytics = FlutterUmamiAnalytics(
        config: makeConfig(),
        collector: _MockCollector(),
        apiClient: api,
      );
      await analytics.dispose();
      expect(api.disposeCalls, 1);
    });
  });

  group('Hexagonal port injection — factory wiring', () {
    DeviceInfoPort fixedDevice() => _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        ));

    test('createUmamiAnalytics accepts an injected HttpClientPort', () async {
      final http = _CaptureHttpClient();
      final analytics = await createUmamiAnalytics(
        makeConfig(queueConfig: const UmamiQueueConfig.disabled()),
        httpClientPort: http,
        deviceInfo: fixedDevice(),
      );
      addTearDown(analytics.dispose);
      await analytics.trackPageView(url: '/injected');
      expect(http.bodies.length, 1);
      expect(http.disposeCalls, 0,
          reason: 'factory must NOT dispose caller-injected port on its own');
      await analytics.dispose();
      expect(http.disposeCalls, 0,
          reason: 'facade must NOT dispose caller-injected HttpClientPort');
    });

    test('createUmamiAnalytics accepts an injected UmamiApiPort', () async {
      final api = _CountingApiPort();
      final analytics = await createUmamiAnalytics(
        makeConfig(queueConfig: const UmamiQueueConfig.disabled()),
        apiClient: api,
        deviceInfo: fixedDevice(),
      );
      addTearDown(analytics.dispose);
      expect(identical(analytics.apiClient, api), true);
      await analytics.dispose();
      expect(api.disposeCalls, 0,
          reason: 'facade must NOT dispose caller-injected UmamiApiPort');
    });

    test(
        'createUmamiAnalytics: injected HttpClientPort takes precedence over '
        'httpClient', () async {
      // Provide both. If httpClientPort wins, bodies land in the capture list.
      // If httpClient won, no body would land (real http.Client would try to
      // hit the network and fail silently, returning false).
      final http = _CaptureHttpClient();
      final analytics = await createUmamiAnalytics(
        makeConfig(queueConfig: const UmamiQueueConfig.disabled()),
        httpClientPort: http,
        httpClient: null,
        deviceInfo: fixedDevice(),
      );
      addTearDown(analytics.dispose);
      await analytics.trackPageView(url: '/precedence');
      expect(http.bodies.length, 1);
    });
  });

  group('TrackingCollector — queue ownership', () {
    DeviceInfoPort fixedDevice() => _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        ));

    test('defaults ownsQueue to true and closes the queue on dispose',
        () async {
      final queue = _CountingQueue();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: _CaptureHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      await collector.dispose();
      expect(queue.closeCalls, 1);
    });

    test('ownsQueue: false does NOT close the queue on dispose', () async {
      final queue = _CountingQueue();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: _CaptureHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
        ownsQueue: false,
      );
      await collector.dispose();
      expect(queue.closeCalls, 0,
          reason: 'caller-injected queue must outlive the collector');
    });
  });

  group('TrackingCollector — queue policy', () {
    DeviceInfoPort fixedDevice() => _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        ));

    test('enqueueEnabled: false drops send failures without touching the queue',
        () async {
      final http = _FailingHttpClient();
      final queue = _CountingQueue();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: http,
        queue: queue,
        deviceInfo: fixedDevice(),
        enqueueEnabled: false,
      );
      addTearDown(collector.dispose);

      final sent = await collector.trackEvent(name: 'drop-me');
      expect(sent, false);
      expect(http.sendCalls, 1);
      expect(queue.inserts, 0,
          reason: 'disabled policy must bypass the queue entirely');
    });

    test('enqueueEnabled: true (default) enqueues on send failure', () async {
      final http = _FailingHttpClient();
      final queue = _CountingQueue();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: http,
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(collector.dispose);

      final sent = await collector.trackEvent(name: 'queue-me');
      expect(sent, false);
      expect(queue.inserts, 1);
    });

    test('flushPurgeTtl: null (default) does not call deleteExpired on flush',
        () async {
      final queue = _CountingQueue();
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: _CaptureHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(collector.dispose);

      await collector.flush();
      expect(queue.deleteExpiredCalls, 0,
          reason: 'null TTL must skip TTL purge entirely');
    });

    test('flushPurgeTtl: 10m calls deleteExpired(10m) on flush', () async {
      final queue = _CountingQueue();
      const ttl = Duration(minutes: 10);
      final collector = TrackingCollector(
        config: makeConfig(),
        httpClient: _CaptureHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
        flushPurgeTtl: ttl,
      );
      addTearDown(collector.dispose);

      await collector.flush();
      expect(queue.deleteExpiredCalls, 1);
      expect(queue.lastDeleteExpiredTtl, ttl);
    });
  });

  group('Hexagonal port injection — queue wiring (createUmamiAnalytics)', () {
    DeviceInfoPort fixedDevice() => _FixedDeviceInfo(const DeviceInfoData(
          screenResolution: '1x1',
          locale: 'en',
          platform: 'test',
        ));

    test('injected UmamiQueue is used and NOT closed on dispose', () async {
      final queue = _CountingQueue();
      final analytics = await createUmamiAnalytics(
        makeConfig(queueConfig: const UmamiQueueConfig.inMemory()),
        httpClientPort: _FailingHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(() async {
        await analytics.dispose();
        await queue.close();
      });
      await analytics.trackEvent(name: 'x');
      expect(queue.inserts, 1,
          reason: 'factory must wire the injected queue into the collector');
      await analytics.dispose();
      expect(queue.closeCalls, 0,
          reason: 'facade must NOT dispose caller-injected UmamiQueue');
    });

    test(
        'injected queue + disabled config => enqueueEnabled=false, drops on '
        'failure', () async {
      final queue = _CountingQueue();
      final analytics = await createUmamiAnalytics(
        makeConfig(queueConfig: const UmamiQueueConfig.disabled()),
        httpClientPort: _FailingHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(() async {
        await analytics.dispose();
        await queue.close();
      });
      await analytics.trackEvent(name: 'dropped');
      expect(queue.inserts, 0,
          reason: 'disabled config + injected queue must still drop events');
    });

    test(
        'injected queue + persisted config => flushPurgeTtl derived from '
        'eventTtl', () async {
      final queue = _CountingQueue();
      const ttl = Duration(hours: 6);
      final analytics = await createUmamiAnalytics(
        makeConfig(
          queueConfig: const PersistedUmamiQueueConfig(
            maxSize: 10,
            eventTtl: ttl,
          ),
        ),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(() async {
        await analytics.dispose();
        await queue.close();
      });
      await analytics.flush();
      expect(queue.deleteExpiredCalls, 1);
      expect(queue.lastDeleteExpiredTtl, ttl,
          reason: 'TTL must come from PersistedUmamiQueueConfig.eventTtl');
    });

    test(
        'injected queue + inMemory config (default) => enqueue on failure, '
        'no TTL purge on flush', () async {
      final queue = _CountingQueue();
      final analytics = await createUmamiAnalytics(
        makeConfig(
          queueConfig: const UmamiQueueConfig.inMemory(maxSize: 5),
        ),
        httpClientPort: _FailingHttpClient(),
        queue: queue,
        deviceInfo: fixedDevice(),
      );
      addTearDown(() async {
        await analytics.dispose();
        await queue.close();
      });
      await analytics.trackEvent(name: 'queued');
      expect(queue.inserts, 1,
          reason: 'inMemory + injected queue must still enqueue on failure');
      await analytics.flush();
      expect(queue.deleteExpiredCalls, 0,
          reason: 'inMemory config must NOT trigger TTL purge');
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

class _CaptureHttpClient implements HttpClientPort {
  final List<Map<String, dynamic>> bodies = [];
  int disposeCalls = 0;

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    bodies.add(body);
    return true;
  }

  @override
  String? get cacheToken => null;

  @override
  void dispose() {
    disposeCalls++;
  }
}

class _NoopQueue implements UmamiQueue {
  @override
  Future<void> insert(String payload) async {}

  @override
  Future<List<QueuedEvent>> getAll() async => const <QueuedEvent>[];

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> deleteExpired(Duration ttl) async {}

  @override
  Future<int> get length async => 0;

  @override
  Future<void> close() async {}
}

class _FixedDeviceInfo implements DeviceInfoPort {
  final DeviceInfoData data;

  _FixedDeviceInfo(this.data);

  @override
  DeviceInfoData gather() => data;
}

class _CountingApiPort implements UmamiApiPort {
  int disposeCalls = 0;
  bool authenticated = false;

  _CountingApiPort();

  @override
  Future<bool> login(String username, String password) async {
    authenticated = true;
    return true;
  }

  @override
  bool get isAuthenticated => authenticated;

  @override
  void dispose() {
    disposeCalls++;
  }

  @override
  Future<List<Map<String, dynamic>>?> getWebsites() async => null;

  @override
  Future<Map<String, dynamic>?> getWebsite(String id) async => null;

  @override
  Future<Map<String, dynamic>?> createWebsite(
          Map<String, dynamic> data) async =>
      null;

  @override
  Future<bool> updateWebsite(String id, Map<String, dynamic> data) async =>
      false;

  @override
  Future<bool> deleteWebsite(String id) async => false;

  @override
  Future<Map<String, dynamic>?> getWebsiteStats(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> getWebsitePageviews(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) async =>
      null;

  @override
  Future<Map<String, dynamic>?> getWebsiteMetrics(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    required String type,
    int? limit,
  }) async =>
      null;

  @override
  Future<int?> getWebsiteActiveVisitors(String id) async => null;

  @override
  Future<List<Map<String, dynamic>>?> getWebsiteEvents(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>?> getWebsiteSessions(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
    String? unit,
    String? timezone,
  }) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>?> getTeams() async => null;

  @override
  Future<Map<String, dynamic>?> createTeam(Map<String, dynamic> data) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>?> getAllUsers() async => null;

  @override
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> data) async =>
      null;

  @override
  Future<bool> deleteUser(String id) async => false;
}

class _CountingQueue implements UmamiQueue {
  int insertCalls = 0;
  int deleteExpiredCalls = 0;
  int closeCalls = 0;
  Duration? lastDeleteExpiredTtl;
  final List<String> _payloads = [];

  int get inserts => insertCalls;

  @override
  Future<void> insert(String payload) async {
    insertCalls++;
    _payloads.add(payload);
  }

  @override
  Future<List<QueuedEvent>> getAll() async => const <QueuedEvent>[];

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> deleteExpired(Duration ttl) async {
    deleteExpiredCalls++;
    lastDeleteExpiredTtl = ttl;
  }

  @override
  Future<int> get length async => _payloads.length;

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

class _FailingHttpClient implements HttpClientPort {
  int sendCalls = 0;
  int disposeCalls = 0;

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    sendCalls++;
    return false;
  }

  @override
  String? get cacheToken => null;

  @override
  void dispose() {
    disposeCalls++;
  }
}
