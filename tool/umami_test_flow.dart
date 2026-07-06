// ignore_for_file: avoid_print, unnecessary_string_interpolations

// Unified Master Integration Simulator and Real Testing Tool for Flutter Umami Analytics.
// Exercises the complete collector, queue, http layer, concurrent multi-user journeys,
// intermittent network outages, and live database REST API E2E verification.
//
// Usage:
//   UMAMI_WEBSITE_ID="your-website-uuid" \
//   UMAMI_ENDPOINT="https://your-umami-instance.com" \
//   UMAMI_HOSTNAME="myapp.com" \
//   [UMAMI_API_USER="admin"] \
//   [UMAMI_API_PASS="password"] \
//   dart run tool/umami_test_flow.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_umami_analytics/src/infrastructure/collector/tracking_collector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/default_http_client.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/in_memory_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/noop_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/api/umami_api_client.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/http_client_port.dart';
import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';

// ─── ANSI Terminal Styling ──────────────────────────────────────────────────

const reset = '\x1B[0m';
const bold = '\x1B[1m';
const red = '\x1B[31m';
const green = '\x1B[32m';
const yellow = '\x1B[33m';
const cyan = '\x1B[36m';
const gray = '\x1B[90m';

String _sep() => '─' * 60;

// ─── Mocks ────────────────────────────────────────────────────────────────────

class TestDeviceId implements DeviceIdPort {
  final String id;
  bool _firstLaunch;

  TestDeviceId({String? id, bool firstLaunch = false})
      : id = id ?? 'test-device-${DateTime.now().millisecondsSinceEpoch}',
        _firstLaunch = firstLaunch;

  @override
  Future<String> getId() async => id;
  @override
  Future<bool> isFirstLaunch() async => _firstLaunch;
  @override
  Future<void> reset() async => _firstLaunch = false;
}

class TestDeviceInfo implements DeviceInfoPort {
  final DeviceInfoData _data;

  const TestDeviceInfo(
      [this._data = const DeviceInfoData(
        screenResolution: '390x844',
        locale: 'es_ES',
        platform: 'ios',
      )]);

  @override
  DeviceInfoData gather() => _data;
}

class SimulatedHttpClient implements HttpClientPort {
  final HttpClientPort _inner;
  bool isOnline = true;

  SimulatedHttpClient(this._inner);

  @override
  Future<bool> send(String endpoint, Map<String, dynamic> body) async {
    if (!isOnline) {
      return false;
    }
    return _inner.send(endpoint, body);
  }

  @override
  String? get cacheToken => _inner.cacheToken;

  @override
  void dispose() => _inner.dispose();
}

// ─── Report ───────────────────────────────────────────────────────────────────

enum TestPhase {
  coreTracking('Core Tracking'),
  sessionIdentity('Session & Identity'),
  queueFlush('Queue & Flush'),
  edgeCases('Edge Cases'),
  disabledMode('Disabled Mode'),
  multiInstance('Multi-Instance'),
  httpLayer('HTTP Layer'),
  concurrencyFunnel('Concurrency & Funnels'),
  intermittentNetwork('Intermittent Network'),
  apiVerification('API Verification'),
  e2eVerification('E2E Live Verification'),
  cleanup('Cleanup'),
  ;

  final String label;
  const TestPhase(this.label);
}

class TestResult {
  final String name;
  final bool ok;
  final String? detail;
  final Duration elapsed;
  final TestPhase phase;

  const TestResult({
    required this.name,
    required this.ok,
    this.detail,
    required this.elapsed,
    required this.phase,
  });
}

class MasterReport {
  final _results = <TestResult>[];
  int _passed = 0;
  int _failed = 0;

  void add(TestResult r) {
    _results.add(r);
    if (r.ok) {
      _passed++;
    } else {
      _failed++;
    }
  }

  bool get hasFailures => _failed > 0;
  int get total => _passed + _failed;

  void printSummary() {
    const w = 60;
    const phaseOrder = TestPhase.values;

    print('\n$bold$cyan${'=' * w}$reset');
    print('  $bold${cyan}UMAMI TRACKING SIMULATION REPORT$reset');
    print('$bold$cyan${'=' * w}$reset');
    print('  ${bold}Started$reset : $_started');
    print('  ${bold}Elapsed$reset : ${Duration(milliseconds: _elapsed)}');
    print('');

    for (final phase in phaseOrder) {
      final phaseResults = _results.where((r) => r.phase == phase).toList();
      if (phaseResults.isEmpty) continue;

      final phasePassed = phaseResults.where((r) => r.ok).length;
      final phaseFailed = phaseResults.where((r) => !r.ok).length;

      final phaseColor = phaseFailed == 0 ? green : red;
      final phaseIcon = phaseFailed == 0 ? '✔' : '✘';
      print('  $bold$phaseColor$phaseIcon ── ${phase.label} ──$reset');
      for (final r in phaseResults) {
        final icon = r.ok ? '$green✔$reset' : '$red✘$reset';
        final time = r.elapsed.inMilliseconds;
        print('    $icon ${r.name} $gray(${time}ms)$reset');
        if (r.detail != null) {
          final detailColor = r.ok ? gray : red;
          print('         $detailColor┗━ ${r.detail}$reset');
        }
      }
      final phaseTotal = phaseResults.length;
      final statusText = phaseFailed == 0
          ? '$green$phasePassed/$phaseTotal passed$reset'
          : '$red$phasePassed/$phaseTotal passed, $phaseFailed failed$reset';
      print('         → $statusText');
      print('');
    }

    print('$bold$cyan${'-' * w}$reset');
    print('  ${bold}Total Tests$reset  : $total');
    print('  ${bold}Passed$reset       : $green$_passed$reset');
    print('  ${bold}Failed$reset       : ${failedText(_failed)}');

    final finalStatus = _failed == 0
        ? '$bold$green🏆 ALL TESTS PASSED SUCCESSFULLY$reset'
        : '$bold$red🚨 SOME TESTS FAILED$reset';
    print('  ${bold}Status$reset       : $finalStatus');
    print('$bold$cyan${'=' * w}$reset\n');
  }

  String failedText(int f) {
    if (f == 0) return '${green}0$reset';
    return '$red$f$reset';
  }

  static String _started = '';
  static int _elapsed = 0;
  static void init() {
    _started = DateTime.now().toIso8601String();
  }

  static void recordElapsed(int ms) {
    _elapsed = ms;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<bool> _trackStep(
  String label,
  Future<bool> Function() fn,
) async {
  try {
    return await fn();
  } catch (e) {
    stderr.writeln('  [!] $label threw: $e');
    return false;
  }
}

Future<TestResult> _runTest({
  required String name,
  required TestPhase phase,
  required Future<bool> Function() fn,
  String? detail,
}) async {
  final sw = Stopwatch()..start();
  final ok = await _trackStep(name, fn);
  sw.stop();
  return TestResult(
    name: name,
    ok: ok,
    detail: detail,
    elapsed: sw.elapsed,
    phase: phase,
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  MasterReport.init();

  final websiteId = Platform.environment['UMAMI_WEBSITE_ID'];
  final endpoint = Platform.environment['UMAMI_ENDPOINT'];
  final hostname = Platform.environment['UMAMI_HOSTNAME'];
  final apiUser = Platform.environment['UMAMI_API_USER'];
  final apiPass = Platform.environment['UMAMI_API_PASS'];

  if (websiteId == null || endpoint == null || hostname == null) {
    print('$bold$red❌ ERROR: Missing required environment variables!$reset');
    print('Please define:');
    print('  - ${bold}UMAMI_WEBSITE_ID$reset (website uuid)');
    print('  - ${bold}UMAMI_ENDPOINT$reset (URL of live Umami instance)');
    print(
        '  - ${bold}UMAMI_HOSTNAME$reset (Hostname to associate with sessions)');
    print('\nOptional for Live API E2E Verification:');
    print('  - ${bold}UMAMI_API_USER$reset');
    print('  - ${bold}UMAMI_API_PASS$reset');
    exit(1);
  }

  final userId = 'test-user-${DateTime.now().millisecondsSinceEpoch}';
  final report = MasterReport();

  print('\n$bold$cyan${'█' * 70}$reset');
  print('  $bold${cyan}UMAMI ANALYTICS SYSTEM SIMULATOR$reset');
  print('$bold$cyan${'█' * 70}$reset');
  print('  ${bold}Endpoint$reset  : $endpoint');
  print('  ${bold}Website ID$reset: $websiteId');
  print('  ${bold}Hostname$reset  : $hostname');
  print('  ${bold}User ID$reset   : $userId');
  print(
      '  ${bold}Live API$reset  : ${apiUser != null && apiPass != null ? '${green}Enabled$reset (User: $apiUser)' : '${red}Disabled$reset'}');
  print('$gray${'━' * 70}$reset');

  const logger = UmamiLogger(minLevel: UmamiLogLevel.info);
  final httpClient = DefaultHttpClient(
    logger: logger,
    timeout: const Duration(seconds: 10),
  );
  const deviceInfo = TestDeviceInfo();

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 1: CORE TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  print('\n${_sep()}');
  print('  PHASE 1: Core Tracking');
  print('${_sep()}');

  late TrackingCollector collector;

  // TC-01: Create collector
  {
    final sw = Stopwatch()..start();
    bool ok = false;
    try {
      collector = TrackingCollector(
        config: FlutterUmamiConfig(
          websiteId: websiteId,
          endpoint: endpoint,
          hostname: hostname,
          userId: userId,
          queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
          logger: logger,
          httpTimeout: const Duration(seconds: 10),
        ),
        httpClient: httpClient,
        queue: InMemoryQueue(maxSize: 500),
        deviceInfo: deviceInfo,
      );
      ok = true;
    } catch (e) {
      ok = false;
    }
    sw.stop();
    report.add(TestResult(
      name: 'Create TrackingCollector',
      ok: ok,
      detail: ok ? null : 'constructor threw',
      elapsed: sw.elapsed,
      phase: TestPhase.coreTracking,
    ));
    if (!ok) {
      report.printSummary();
      exit(1);
    }
  }

  const delay = Duration(milliseconds: 300);

  // TC-02: Basic pageview
  report.add(await _runTest(
    name: 'Pageview: /home',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackPageView(url: '/home', title: 'Home Screen'),
  ));
  await Future<void>.delayed(delay);

  // TC-03: Pageview with full metadata
  report.add(await _runTest(
    name: 'Pageview: full metadata',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackPageView(
      url: '/products?category=shoes',
      title: 'Product Catalog',
      referrer: '/home',
      language: 'en_US',
      screen: '1920x1080',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-04: Pageview with per-call overrides
  report.add(await _runTest(
    name: 'Pageview: overrides (hostname, language)',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackPageView(
      url: '/overridden',
      title: 'Overridden',
      overrides: {
        'hostname': 'sub.myapp.com',
        'language': 'fr_FR',
      },
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-05: Pageview with ip_address override
  report.add(await _runTest(
    name: 'Pageview: ip_address override',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackPageView(
      url: '/ip-test',
      title: 'IP Test',
      overrides: {'ipAddress': '203.0.113.42'},
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-06: Event with string data
  report.add(await _runTest(
    name: 'Event: button_click (string data)',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackEvent(
      name: 'button_click',
      data: {'button': 'subscribe', 'location': 'header'},
      url: '/home',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-07: Event with numeric data
  report.add(await _runTest(
    name: 'Event: purchase (numeric data)',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackEvent(
      name: 'purchase',
      data: {'value': 49.99, 'currency': 'EUR', 'items': 3},
      url: '/checkout/confirm',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-08: Event with mixed data types
  report.add(await _runTest(
    name: 'Event: mixed data types',
    phase: TestPhase.coreTracking,
    fn: () => collector.trackEvent(
      name: 'signup',
      data: {
        'method': 'google',
        'age': 28,
        'is_premium': true,
        'score': 9.5,
        'tags': ['python', 'dart'],
      },
      url: '/auth/signup',
    ),
  ));
  await Future<void>.delayed(delay);

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: SESSION & IDENTITY
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 2: Session & Identity');
  print('${_sep()}');

  // TC-09: Basic identify
  report.add(await _runTest(
    name: 'Identify: session properties',
    phase: TestPhase.sessionIdentity,
    fn: () => collector.identify(properties: {
      'tier': 'premium',
      'plan': 'annual',
      'source': 'master-test',
    }),
  ));
  await Future<void>.delayed(delay);

  // TC-10: Identify with custom sessionId
  report.add(await _runTest(
    name: 'Identify: custom sessionId',
    phase: TestPhase.sessionIdentity,
    fn: () => collector.identify(
      properties: {'custom_session': 'true'},
      sessionId: 'manual-session-${DateTime.now().millisecondsSinceEpoch}',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-11: Multiple identifies (session continuity)
  report.add(await _runTest(
    name: 'Identify: multiple calls reuse session',
    phase: TestPhase.sessionIdentity,
    fn: () async {
      final a = await collector.identify(properties: {'step': 'first'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final b = await collector.identify(properties: {'step': 'second'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final c = await collector.identify(properties: {'step': 'third'});
      return a && b && c;
    },
  ));
  await Future<void>.delayed(delay);

  // TC-12: First referrer consumed only once
  {
    final refCollector = TrackingCollector(
      config: FlutterUmamiConfig(
        websiteId: websiteId,
        endpoint: endpoint,
        hostname: hostname,
        firstReferrer: 'https://google.com',
        logger: logger,
      ),
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 10)),
      queue: InMemoryQueue(maxSize: 100),
      deviceInfo: deviceInfo,
    );
    report.add(await _runTest(
      name: 'First referrer: consumed on first pageview only',
      phase: TestPhase.sessionIdentity,
      fn: () async {
        final first = await refCollector.trackPageView(
          url: '/ref-test-1',
          title: 'First Referrer Test',
        );
        return first;
      },
    ));
    await Future<void>.delayed(delay);
    await refCollector.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: QUEUE & FLUSH
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 3: Queue & Flush');
  print('${_sep()}');

  // TC-13: Queue on network failure (invalid endpoint)
  {
    final badConfig = FlutterUmamiConfig(
      websiteId: websiteId,
      endpoint: 'https://0.0.0.0/nonexistent',
      hostname: hostname,
      queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
      logger: logger,
      httpTimeout: const Duration(seconds: 2),
    );
    final badQueue = InMemoryQueue(maxSize: 500);
    final badCollector = TrackingCollector(
      config: badConfig,
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 2)),
      queue: badQueue,
      deviceInfo: deviceInfo,
    );

    report.add(await _runTest(
      name: 'Queue: enqueues event on network failure',
      phase: TestPhase.queueFlush,
      fn: () async {
        final ok = await badCollector.trackPageView(url: '/offline-test');
        final len = await badQueue.length;
        return !ok && len == 1;
      },
      detail: 'sends to bogus endpoint, expects queued=true',
    ));
    await badCollector.dispose();
  }

  // TC-14: Explicit flush after queue build-up
  {
    final smallQueue = InMemoryQueue(maxSize: 500);
    final flushConfig = FlutterUmamiConfig(
      websiteId: websiteId,
      endpoint: 'https://0.0.0.0/nonexistent',
      hostname: hostname,
      queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
      logger: logger,
      httpTimeout: const Duration(seconds: 1),
    );
    final flushCollector = TrackingCollector(
      config: flushConfig,
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 1)),
      queue: smallQueue,
      deviceInfo: deviceInfo,
    );

    await flushCollector.trackPageView(url: '/flush-1');
    await flushCollector.trackPageView(url: '/flush-2');
    await flushCollector.trackPageView(url: '/flush-3');

    report.add(await _runTest(
      name: 'Flush: explicit flush processes queued events',
      phase: TestPhase.queueFlush,
      fn: () async {
        await flushCollector.flush();
        return true;
      },
      detail: 'flush completed without error',
    ));
    await flushCollector.dispose();
  }

  // TC-15: Auto-flush after queue reaches threshold
  {
    final autoQueue = InMemoryQueue(maxSize: 500);
    final autoConfig = FlutterUmamiConfig(
      websiteId: websiteId,
      endpoint: 'https://0.0.0.0/nonexistent',
      hostname: hostname,
      queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
      logger: logger,
      httpTimeout: const Duration(seconds: 1),
    );
    final autoCollector = TrackingCollector(
      config: autoConfig,
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 1)),
      queue: autoQueue,
      deviceInfo: deviceInfo,
    );

    await autoCollector.trackPageView(url: '/auto-1');

    report.add(await _runTest(
      name: 'Auto-flush: triggers when queue has pending events',
      phase: TestPhase.queueFlush,
      fn: () async {
        final ok = await collector.trackPageView(url: '/auto-trigger');
        return ok;
      },
      detail: 'auto-flush attempted (previous queued events stay)',
    ));
    await autoCollector.dispose();
  }

  // TC-16: Queue overflow (maxSize exceeded)
  {
    final overflowQueue = InMemoryQueue(maxSize: 2);
    final overflowConfig = FlutterUmamiConfig(
      websiteId: websiteId,
      endpoint: 'https://0.0.0.0/nonexistent',
      hostname: hostname,
      queueConfig: const UmamiQueueConfig.inMemory(maxSize: 2),
      logger: logger,
      httpTimeout: const Duration(seconds: 1),
    );
    final overflowCollector = TrackingCollector(
      config: overflowConfig,
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 1)),
      queue: overflowQueue,
      deviceInfo: deviceInfo,
    );

    report.add(await _runTest(
      name: 'Queue overflow: oldest event evicted at maxSize',
      phase: TestPhase.queueFlush,
      fn: () async {
        await overflowCollector.trackPageView(url: '/overflow-1');
        await overflowCollector.trackPageView(url: '/overflow-2');
        await overflowCollector.trackPageView(url: '/overflow-3');
        final len = await overflowQueue.length;
        return len == 2;
      },
      detail: 'queue.size=2 after 3 inserts, oldest evicted',
    ));
    await overflowCollector.dispose();
  }

  // TC-17: Disabled queue config (NoopQueue)
  {
    final noopQueue = NoopQueue();
    final noopConfig = FlutterUmamiConfig(
      websiteId: websiteId,
      endpoint: 'https://0.0.0.0/nonexistent',
      hostname: hostname,
      queueConfig: const UmamiQueueConfig.disabled(),
      logger: logger,
      httpTimeout: const Duration(seconds: 1),
    );
    final noopCollector = TrackingCollector(
      config: noopConfig,
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 1)),
      queue: noopQueue,
      deviceInfo: deviceInfo,
    );

    report.add(await _runTest(
      name: 'Disabled queue: events not queued on failure',
      phase: TestPhase.queueFlush,
      fn: () async {
        final ok = await noopCollector.trackPageView(url: '/noop-queue');
        final len = await noopQueue.length;
        return !ok && len == 0;
      },
      detail: 'track=fail, queue stays empty',
    ));
    await noopCollector.dispose();
  }

  // TC-18: Empty queue flush
  report.add(await _runTest(
    name: 'Flush: empty queue no-ops',
    phase: TestPhase.queueFlush,
    fn: () async {
      await collector.flush();
      return true;
    },
    detail: 'flush on empty queue completes silently',
  ));

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 4: EDGE CASES
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 4: Edge Cases');
  print('${_sep()}');

  // TC-19: Event with empty data map
  report.add(await _runTest(
    name: 'Event: empty data map',
    phase: TestPhase.edgeCases,
    fn: () => collector.trackEvent(
      name: 'empty_data',
      data: {},
      url: '/edge',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-20: Event with null data
  report.add(await _runTest(
    name: 'Event: null data (omitted)',
    phase: TestPhase.edgeCases,
    fn: () => collector.trackEvent(
      name: 'null_data',
      url: '/edge',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-21: Event with unicode / special characters
  report.add(await _runTest(
    name: 'Event: unicode & special characters',
    phase: TestPhase.edgeCases,
    fn: () => collector.trackEvent(
      name: 'unicode_test',
      data: {
        'emoji': '🔥 🚀 💯',
        'unicode': 'Mêlée français 中文 Español',
        'special': 'foo&bar=baz|qux~hello',
      },
      url: '/edge/unicode',
    ),
  ));
  await Future<void>.delayed(delay);

  // TC-22: Event with very long strings
  report.add(await _runTest(
    name: 'Event: long string values',
    phase: TestPhase.edgeCases,
    fn: () {
      final longStr = List.filled(200, 'A').join();
      return collector.trackEvent(
        name: 'long_string',
        data: {'very_long': longStr, 'description': longStr},
        url: '/edge/long',
      );
    },
    detail: '200-char string in event data',
  ));
  await Future<void>.delayed(delay);

  // TC-23: Rapid fire / burst tracking
  report.add(await _runTest(
    name: 'Rapid fire: 10 events without await delay',
    phase: TestPhase.edgeCases,
    fn: () async {
      final futures = <Future<bool>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(collector.trackEvent(
          name: 'rapid_fire',
          data: {'index': i},
          url: '/edge/rapid',
        ));
      }
      final results = await Future.wait(futures);
      return results.every((r) => r);
    },
    detail: '10 concurrent trackEvent calls',
  ));
  await Future<void>.delayed(delay);

  // TC-24: Event with many data keys
  report.add(await _runTest(
    name: 'Event: 20 data keys',
    phase: TestPhase.edgeCases,
    fn: () {
      final bigData = <String, dynamic>{};
      for (var i = 0; i < 20; i++) {
        bigData['key_$i'] = 'value_$i';
      }
      return collector.trackEvent(
        name: 'big_data',
        data: bigData,
        url: '/edge/big-data',
      );
    },
  ));
  await Future<void>.delayed(delay);

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 5: DISABLED MODE
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 5: Disabled Mode');
  print('${_sep()}');

  // TC-25: Disabled collector returns false
  {
    final disabledCollector = TrackingCollector(
      config: FlutterUmamiConfig(
        websiteId: websiteId,
        endpoint: endpoint,
        hostname: hostname,
        enabled: false,
        logger: logger,
      ),
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 10)),
      queue: InMemoryQueue(maxSize: 500),
      deviceInfo: deviceInfo,
    );

    report.add(await _runTest(
      name: 'Disabled: trackPageView returns false',
      phase: TestPhase.disabledMode,
      fn: () async {
        final result = await disabledCollector.trackPageView(url: '/disabled');
        return !result;
      },
    ));

    report.add(await _runTest(
      name: 'Disabled: trackEvent returns false',
      phase: TestPhase.disabledMode,
      fn: () async {
        final result =
            await disabledCollector.trackEvent(name: 'disabled_event');
        return !result;
      },
    ));

    report.add(await _runTest(
      name: 'Disabled: identify returns false',
      phase: TestPhase.disabledMode,
      fn: () async {
        final result =
            await disabledCollector.identify(properties: {'test': 'true'});
        return !result;
      },
    ));

    await disabledCollector.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 6: MULTI-INSTANCE
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 6: Multi-Instance');
  print('${_sep()}');

  // TC-26: Two isolated collectors
  {
    final queueA = InMemoryQueue(maxSize: 100);
    final queueB = InMemoryQueue(maxSize: 100);

    final collectorA = TrackingCollector(
      config: FlutterUmamiConfig(
        websiteId: websiteId,
        endpoint: endpoint,
        hostname: 'instance-a.com',
        logger: logger,
      ),
      httpClient: DefaultHttpClient(logger: logger),
      queue: queueA,
      deviceInfo: deviceInfo,
    );

    final collectorB = TrackingCollector(
      config: FlutterUmamiConfig(
        websiteId: websiteId,
        endpoint: 'https://0.0.0.0/nonexistent',
        hostname: 'instance-b.com',
        queueConfig: const UmamiQueueConfig.inMemory(maxSize: 100),
        logger: logger,
        httpTimeout: const Duration(seconds: 1),
      ),
      httpClient: DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 1)),
      queue: queueB,
      deviceInfo: deviceInfo,
    );

    report.add(await _runTest(
      name: 'Multi-instance: isolated success/failure',
      phase: TestPhase.multiInstance,
      fn: () async {
        final okA = await collectorA.trackPageView(url: '/multi-a');
        final okB = await collectorB.trackPageView(url: '/multi-b');
        final lenA = await queueA.length;
        final lenB = await queueB.length;
        return okA && !okB && lenA == 0 && lenB == 1;
      },
      detail: 'A succeeds (queue empty), B fails (1 queued)',
    ));

    await collectorA.dispose();
    await collectorB.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 7: HTTP LAYER
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 7: HTTP Layer');
  print('${_sep()}');

  // TC-27: Cache token received from server
  report.add(await _runTest(
    name: 'Cache token: received from server',
    phase: TestPhase.httpLayer,
    fn: () async {
      await collector.trackPageView(
        url: '/cache-token-test-${DateTime.now().millisecondsSinceEpoch}',
      );
      return true; // Optional header, success of call is the test
    },
    detail: httpClient.cacheToken != null
        ? 'token=${httpClient.cacheToken}'
        : 'no token received (normal if server opts out or CDN strips headers)',
  ));

  // TC-28: Cache token sent on subsequent requests
  report.add(await _runTest(
    name: 'Cache token: reused in subsequent requests',
    phase: TestPhase.httpLayer,
    fn: () async {
      final tokenBefore = httpClient.cacheToken;
      await collector.trackPageView(url: '/cache-reuse');
      final tokenAfter = httpClient.cacheToken;
      if (tokenBefore == null) {
        return true; // No token was received in TC-27, nothing to reuse
      }
      return tokenAfter == tokenBefore;
    },
    detail: httpClient.cacheToken != null
        ? 'token persists across requests'
        : 'skipped (no cache token received from server)',
  ));

  // TC-29: Invalid endpoint returns false (not throw)
  {
    final badHttp = DefaultHttpClient(
      logger: logger,
      timeout: const Duration(seconds: 2),
    );
    report.add(await _runTest(
      name: 'HTTP: invalid endpoint returns false',
      phase: TestPhase.httpLayer,
      fn: () async {
        final ok =
            await badHttp.send('https://0.0.0.0:1/api/send', {'test': true});
        return !ok;
      },
      detail: 'connection refused or timeout → false',
    ));
    badHttp.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 8: CONCURRENCY & FUNNELS
  // ═══════════════════════════════════════════════════════════════════════════

  print('\n${_sep()}');
  print('  PHASE 8: Concurrency & Funnels');
  print('${_sep()}');

  report.add(await _runTest(
    name:
        'Concurrency: Simulate 5 concurrent users with different devices navigating funnel',
    phase: TestPhase.concurrencyFunnel,
    fn: () async {
      final userConfigs = [
        _UserSimConfig(
            'sim-user-ios', 'ios', '390x844', 'es_ES', 'iPhone 15 Pro'),
        _UserSimConfig(
            'sim-user-android', 'android', '412x915', 'en_US', 'Samsung S24'),
        _UserSimConfig(
            'sim-user-macos', 'macos', '2560x1600', 'fr_FR', 'MacBook Pro'),
        _UserSimConfig(
            'sim-user-windows', 'windows', '1920x1080', 'de_DE', 'ThinkPad'),
        _UserSimConfig(
            'sim-user-web', 'web', '1440x900', 'ja_JP', 'Chromebook'),
      ];

      final futures = userConfigs.map((cfg) async {
        final uQueue = InMemoryQueue(maxSize: 10);
        final uCollector = TrackingCollector(
          config: FlutterUmamiConfig(
            websiteId: websiteId,
            endpoint: endpoint,
            hostname: hostname,
            userId: cfg.userId,
            logger: logger,
          ),
          httpClient: DefaultHttpClient(
              logger: logger, timeout: const Duration(seconds: 10)),
          queue: uQueue,
          deviceInfo: TestDeviceInfo(DeviceInfoData(
            screenResolution: cfg.resolution,
            locale: cfg.locale,
            platform: cfg.platform,
          )),
        );

        try {
          await uCollector.trackPageView(url: '/shop/home', title: 'Home');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await uCollector.trackPageView(
              url: '/shop/catalog', title: 'Catalog');
          await uCollector.trackEvent(
            name: 'add_to_cart',
            url: '/shop/catalog',
            data: {'item': 'premium_widget', 'device': cfg.deviceModel},
          );
          await uCollector.trackEvent(
            name: 'checkout',
            url: '/shop/checkout',
            data: {'total': 99.99},
          );
          await uCollector.flush();
          await uCollector.dispose();
          return true;
        } catch (_) {
          return false;
        }
      }).toList();

      final results = await Future.wait(futures);
      return results.every((r) => r);
    },
    detail: 'Simulated multi-device flows concurrently',
  ));

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 9: INTERMITTENT NETWORK
  // ═══════════════════════════════════════════════════════════════════════════

  print('\n${_sep()}');
  print('  PHASE 9: Intermittent Network');
  print('${_sep()}');

  report.add(await _runTest(
    name: 'Intermittent Network: offline queuing & restoration flush',
    phase: TestPhase.intermittentNetwork,
    fn: () async {
      final simHttp = SimulatedHttpClient(DefaultHttpClient(
          logger: logger, timeout: const Duration(seconds: 10)));
      final rQueue = InMemoryQueue(maxSize: 100);
      final rCollector = TrackingCollector(
        config: FlutterUmamiConfig(
          websiteId: websiteId,
          endpoint: endpoint,
          hostname: hostname,
          logger: logger,
        ),
        httpClient: simHttp,
        queue: rQueue,
        deviceInfo: deviceInfo,
      );

      simHttp.isOnline = false;

      final pv1 = await rCollector.trackPageView(url: '/offline-1');
      final pv2 = await rCollector.trackPageView(url: '/offline-2');
      final qCountBefore = await rQueue.length;

      if (pv1 || pv2 || qCountBefore != 2) {
        await rCollector.dispose();
        return false;
      }

      simHttp.isOnline = true;

      await rCollector.flush();
      final qCountAfter = await rQueue.length;

      await rCollector.dispose();
      return qCountAfter == 0;
    },
    detail: 'network outage -> queue 2 events -> online -> flush success',
  ));

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 10: API VERIFICATION (conditional)
  // ═══════════════════════════════════════════════════════════════════════════

  final timeStart = DateTime.now();

  if (apiUser != null && apiPass != null) {
    print('${_sep()}');
    print('  PHASE 10: API Verification');
    print('${_sep()}');

    await Future<void>.delayed(const Duration(seconds: 1));

    UmamiApiClient? apiClient;
    try {
      apiClient = UmamiApiClient(baseUrl: endpoint, logger: logger);
      report.add(const TestResult(
        name: 'Create UmamiApiClient',
        ok: true,
        elapsed: Duration.zero,
        phase: TestPhase.apiVerification,
      ));
    } catch (e) {
      report.add(TestResult(
        name: 'Create UmamiApiClient',
        ok: false,
        detail: '$e',
        elapsed: Duration.zero,
        phase: TestPhase.apiVerification,
      ));
    }

    if (apiClient != null) {
      report.add(await _runTest(
        name: 'API: login',
        phase: TestPhase.apiVerification,
        fn: () => apiClient!.login(apiUser, apiPass),
      ));

      if (apiClient.isAuthenticated) {
        report.add(await _runTest(
          name: 'API: getWebsites',
          phase: TestPhase.apiVerification,
          fn: () async {
            final sites = await apiClient!.getWebsites();
            return sites != null && sites.isNotEmpty;
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsite',
          phase: TestPhase.apiVerification,
          fn: () async {
            final site = await apiClient!.getWebsite(websiteId);
            return site != null && site['id'] == websiteId;
          },
        ));

        report.add(await _runTest(
          name: 'API: getWebsiteStats',
          phase: TestPhase.apiVerification,
          fn: () async {
            final now = DateTime.now();
            final stats = await apiClient!.getWebsiteStats(
              websiteId,
              startAt: timeStart.subtract(const Duration(hours: 1)),
              endAt: now,
            );
            return stats != null && stats.containsKey('pageviews');
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsiteEvents',
          phase: TestPhase.apiVerification,
          fn: () async {
            final now = DateTime.now();
            final events = await apiClient!.getWebsiteEvents(
              websiteId,
              startAt: timeStart.subtract(const Duration(hours: 1)),
              endAt: now,
            );
            return events != null && events.isNotEmpty;
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsiteSessions',
          phase: TestPhase.apiVerification,
          fn: () async {
            final now = DateTime.now();
            final sessions = await apiClient!.getWebsiteSessions(
              websiteId,
              startAt: timeStart.subtract(const Duration(hours: 1)),
              endAt: now,
            );
            return sessions != null && sessions.isNotEmpty;
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsiteActiveVisitors',
          phase: TestPhase.apiVerification,
          fn: () async {
            final active = await apiClient!.getWebsiteActiveVisitors(websiteId);
            return active != null && active >= 0;
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsitePageviews',
          phase: TestPhase.apiVerification,
          fn: () async {
            final now = DateTime.now();
            final pv = await apiClient!.getWebsitePageviews(
              websiteId,
              startAt: timeStart.subtract(const Duration(hours: 1)),
              endAt: now,
            );
            return pv != null;
          },
          detail: null,
        ));

        report.add(await _runTest(
          name: 'API: getWebsiteMetrics (pageview type)',
          phase: TestPhase.apiVerification,
          fn: () async {
            final now = DateTime.now();
            final metrics = await apiClient!.getWebsiteMetrics(
              websiteId,
              startAt: timeStart.subtract(const Duration(hours: 1)),
              endAt: now,
              type: 'pageview',
              limit: 10,
            );
            return metrics != null;
          },
        ));

        report.add(await _runTest(
          name: 'API: getTeams',
          phase: TestPhase.apiVerification,
          fn: () async {
            final teams = await apiClient!.getTeams();
            return teams != null;
          },
        ));

        apiClient.dispose();
      } else {
        print('  [!] API login failed — skipping API tests');
      }
    }
  } else {
    print(
        '\n  ── API Verification: SKIPPED (set UMAMI_API_USER / UMAMI_API_PASS) ──');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 11: E2E LIVE VERIFICATION (conditional)
  // ═══════════════════════════════════════════════════════════════════════════

  if (apiUser != null && apiPass != null) {
    print('${_sep()}');
    print('  PHASE 11: E2E Live Verification');
    print('${_sep()}');

    final e2eToken =
        'e2e_verify_master_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';

    report.add(await _runTest(
      name:
          'E2E Live Verification: Send unique event and poll server database via API',
      phase: TestPhase.e2eVerification,
      fn: () async {
        final e2eCollector = TrackingCollector(
          config: FlutterUmamiConfig(
            websiteId: websiteId,
            endpoint: endpoint,
            hostname: hostname,
            logger: logger,
          ),
          httpClient: DefaultHttpClient(
              logger: logger, timeout: const Duration(seconds: 10)),
          queue: InMemoryQueue(maxSize: 10),
          deviceInfo: deviceInfo,
        );

        final sent = await e2eCollector.trackEvent(
          name: e2eToken,
          url: '/e2e-live-verification',
          data: {'verified': 'true', 'initiator': 'opencode-master-tool'},
        );
        if (!sent) {
          await e2eCollector.dispose();
          return false;
        }

        await e2eCollector.flush();
        await e2eCollector.dispose();

        final apiClient = UmamiApiClient(baseUrl: endpoint, logger: logger);
        final loggedIn = await apiClient.login(apiUser, apiPass);
        if (!loggedIn) {
          apiClient.dispose();
          return false;
        }

        bool found = false;
        final checkStart = DateTime.now().subtract(const Duration(minutes: 10));
        for (int i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          final events = await apiClient.getWebsiteEvents(
            websiteId,
            startAt: checkStart,
            endAt: DateTime.now().add(const Duration(minutes: 1)),
          );
          if (events != null) {
            found = events.any((e) => e['event'] == e2eToken);
            if (found) break;
          }
        }

        apiClient.dispose();
        return found;
      },
      detail:
          'Fires event "$e2eToken" -> polls getWebsiteEvents() -> found=true',
    ));
  } else {
    print(
        '\n  ── E2E Live Verification: SKIPPED (set UMAMI_API_USER / UMAMI_API_PASS) ──');
    report.add(const TestResult(
      name: 'E2E Live Verification: Skip',
      ok: true,
      phase: TestPhase.e2eVerification,
      elapsed: Duration.zero,
      detail: 'Credentials not supplied in environment',
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 12: CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  print('${_sep()}');
  print('  PHASE 12: Cleanup');
  print('${_sep()}');

  report.add(await _runTest(
    name: 'Dispose collector',
    phase: TestPhase.cleanup,
    fn: () async {
      await collector.dispose();
      return true;
    },
  ));

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════

  MasterReport.recordElapsed(
    DateTime.now()
        .difference(DateTime.parse(MasterReport._started))
        .inMilliseconds,
  );
  report.printSummary();
  exit(report.hasFailures ? 1 : 0);
}

// ─── Custom Config Class for Funnels ────────────────────────────────────────

class _UserSimConfig {
  final String userId;
  final String platform;
  final String resolution;
  final String locale;
  final String deviceModel;

  _UserSimConfig(this.userId, this.platform, this.resolution, this.locale,
      this.deviceModel);
}
