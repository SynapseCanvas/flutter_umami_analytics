# Advanced

Advanced usage patterns: `first_open` event, port substitution, custom HTTP client, manual facade construction, and references to specialized topics.

## The `first_open` Event

If you pass `recordFirstOpen: true` to [createUmamiAnalytics()], a `first_open` event (with `url: '/app/launch'`) is sent automatically the first time the user opens the app.

```dart
final analytics = await createUmamiAnalytics(
  config,
  recordFirstOpen: true,
);
```

Persistence and resending:

- The "first launch" flag is stored in `flutter_secure_storage` under the key `umami_first_launch{instanceName}` (empty when `instanceName` is `null`).
- **iOS / macOS**: `flutter_secure_storage` is backed by Keychain, which **survives uninstall**. The event fires only once per device.
- **Android**: uses `EncryptedSharedPreferences`, which **is cleared on uninstall** or when the app data is wiped. In those cases `first_open` is resent.

The `recordFirstOpen` parameter (default `false`) enables construction of the `DeviceIdPort`; if you leave it `false`, no "first launch" key is written or read. Each `instanceName` keeps its own counter.

[createUmamiAnalytics()]: 1-initialization.md

## Custom Collector

Implement `UmamiCollector` to control the send lifecycle (routing, batching, filtering, etc.):

```dart
class CustomCollector implements UmamiCollector {
  @override
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
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
    UmamiConfigOverrides? overrides,
  }) async {
    return true;
  }

  @override
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  }) async {
    return true;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {}
}
```

Inject it by constructing the facade by hand (see [Manual facade construction](#manual-facade-construction)) or by replacing it in your tests.

### What You Lose by Replacing `TrackingCollector`

`TrackingCollector` (the default implementation) orchestrates several mechanisms. If you replace it with your own implementation, you lose:

- The `FlutterUmamiConfig.enabled` check (the facade does this, not the collector).
- The offline queue (`UmamiQueue`) with retries.
- One-shot consumption of `firstReferrer` on the first `trackPageView`.
- Lazy generation and reuse of `sessionId` in `identify`.
- Automatic capture of `hostname`, `language`, and `screen` from the device via `DeviceInfoPort`.
- Posting to `/api/send` with `safeAsync` (errors are only logged, never propagated).

### Alternative: Composition

If you only need to intercept some calls, **wrap** `TrackingCollector` instead of reimplementing the whole port:

```dart
class FilteringCollector implements UmamiCollector {
  FilteringCollector(this._inner);
  final UmamiCollector _inner;

  @override
  Future<bool> trackEvent({
    required String name,
    String? url,
    Map<String, dynamic>? data,
    /* ... rest of params ... */
    UmamiConfigOverrides? overrides,
  }) async {
    if (name == 'spam') return false; // filter
    return _inner.trackEvent(
      name: name,
      url: url,
      data: data,
      overrides: overrides,
    );
  }

  @override
  Future<bool> trackPageView({required String url, /* ... */}) =>
      _inner.trackPageView(url: url /* ... */);

  @override
  Future<bool> identify({required Map<String, dynamic> properties, /* ... */}) =>
      _inner.identify(properties: properties /* ... */);

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future<void> dispose() => _inner.dispose();
}
```

This way you keep the queue, referrer, session, and device capture without reimplementing them.

## Custom HTTP Client

`createUmamiAnalytics()` accepts an `http.Client` to tune timeouts, certificates, proxy, cache, etc. The same client is shared by `DefaultHttpClient` (tracking) and `UmamiApiClient` (REST API) when you pass it.

```dart
final analytics = await createUmamiAnalytics(
  config,
  httpClient: myCustomClient,
);
```

### Ownership and Lifecycle

| Client source            | `_ownsClient` | `dispose()` closes it |
| ------------------------ | ------------- | --------------------- |
| `httpClient: null` (def) | `true`        | Yes                   |
| `httpClient: myClient`   | `false`       | **No**                |

If you inject your own `http.Client`, **you are responsible for closing it**. The facade's `dispose()` cascade will not do it. Useful for sharing connections across services:

```dart
final sharedClient = http.Client();
try {
  final analytics = await createUmamiAnalytics(config, httpClient: sharedClient);
  // ...use analytics...
  await analytics.dispose(); // does NOT close sharedClient
} finally {
  sharedClient.close(); // you close it
}
```

### Timeout

`httpTimeout` in `FlutterUmamiConfig` (default `Duration(seconds: 5)`) applies **only** to the internal `DefaultHttpClient`. If you inject your own client, configure the timeout on it.

## Manual Facade Construction

`createUmamiAnalytics()` is the recommended path. If you need full control over each adapter (tests, alternative backends, lazy init), construct `FlutterUmamiAnalytics` directly:

```dart
final analytics = FlutterUmamiAnalytics(
  config: config,
  collector: TrackingCollector(
    config: config,
    httpClient: httpAdapter,
    queue: queue,
    deviceInfo: deviceInfoService,
  ),
  apiClient: myApiPort, // UmamiApiPort? optional
);
```

Considerations:

- `TrackingCollector` and `UmamiApiClient` are internal adapters (`infrastructure` layer), **not exported** by the `lib/flutter_umami_analytics.dart` barrel. To use them you need a direct `import 'package:flutter_umami_analytics/src/...'` (which breaks the barrel encapsulation) or limit yourself to implementing the ports (`UmamiCollector`, `UmamiApiPort`) yourself.
- The facade does not call `flush()` automatically in `dispose()`. Call `flush()` first if you need to deliver the pending queue.
- You are responsible for wiring `DeviceIdPort` / `DeviceInfoPort` if your adapters require them.

See also [Port substitution] in [9-api-client.md] for the specific case of the REST client.

[9-api-client.md]: 9-api-client.md
[Port substitution]: 9-api-client.md#port-substitution

## Exposed Components

The instance exposes:

```dart
analytics.config      // FlutterUmamiConfig
analytics.collector   // UmamiCollector (port)
analytics.apiClient   // UmamiApiPort?
analytics.logger      // UmamiLogger (alias of config.logger)
```

Direct access to the collector for tests or calls that bypass the facade:

```dart
await analytics.collector.trackEvent(name: 'custom', data: {'k': 'v'});
```

> Remember: calling the collector directly **bypasses** the `config.enabled` check performed by the facade. Use it only when you know you want to emit unconditionally.

Typical usage of the authenticated REST client (when `enableApi: true`):

```dart
if (analytics.apiClient?.isAuthenticated ?? false) {
  final stats = await analytics.apiClient!.getWebsiteStats(
    config.websiteId,
    startAt: DateTime.now().subtract(const Duration(days: 7)),
    endAt: DateTime.now(),
  );
}
```

More details in [9-api-client.md].

## Injection into the Widget Tree

Pass the instance through the tree or inject it via a DI container (Provider, Riverpod, GetIt, etc.):

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({required this.analytics, super.key});
  final FlutterUmamiAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => analytics.trackEvent(name: 'button_click'),
      child: const Text('Click me'),
    );
  }
}
```

## References to Advanced Topics

| Topic                           | Document                                                      |
| ------------------------------- | ------------------------------------------------------------- |
| Per-call overrides              | [6-overrides.md](6-overrides.md)                              |
| `UmamiNavigatorObserver`        | [4-observer.md](4-observer.md)                                |
| Offline queue and persistence   | [2-queue.md](2-queue.md)                                      |
| Device IDs and info             | [7-device.md](7-device.md)                                    |
| Logging and levels              | [8-logging.md](8-logging.md)                                  |
| REST client (`UmamiApiPort`)    | [9-api-client.md](9-api-client.md)                            |
| Multi-instance (`instanceName`) | [1-initialization.md](1-initialization.md#multiple-instances) |
