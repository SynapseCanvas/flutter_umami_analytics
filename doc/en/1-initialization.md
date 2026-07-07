# Initialization

## `createUmamiAnalytics()`

Creates an analytics instance. Call it before any tracking operation.

```dart
final analytics = await createUmamiAnalytics(
  const FlutterUmamiConfig(
    websiteId: 'your-website-id',
    endpoint: 'https://your-umami-instance.com',
    hostname: 'myapp.com',
  ),
);
```

### Parameters of `createUmamiAnalytics()`

| Parameter         | Type                 | Default  | Description                                                                                                              |
| ----------------- | -------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| `config`          | `FlutterUmamiConfig` | required | Instance configuration                                                                                                   |
| `httpClient`      | `http.Client?`       | `null`   | Custom HTTP client. If passed, it is shared by `DefaultHttpClient` and `UmamiApiClient`; otherwise each creates its own. |
| `deviceId`        | `DeviceIdPort?`      | `null`   | Device ID service (only built/used when `recordFirstOpen: true`)                                                         |
| `deviceInfo`      | `DeviceInfoPort?`    | `null`   | Device info service. Default: `DefaultDeviceInfoService`.                                                                |
| `recordFirstOpen` | `bool`               | `false`  | On first run (according to `flutter_secure_storage`), sends a `first_open` event with URL `/app/launch`                  |
| `enableApi`       | `bool`               | `false`  | Enables the REST API client (`analytics.apiClient`). See [9-api-client.md](9-api-client.md).                             |
| `apiUsername`     | `String?`            | `null`   | Auto-login in `createUmamiAnalytics()` only when **both** `apiUsername` and `apiPassword` are present                    |
| `apiPassword`     | `String?`            | `null`   | Password for auto-login. If login fails or throws, `apiClient` stays `null` (graceful degradation)                       |

> 🔐 **Security**: `apiUsername`/`apiPassword` are **secrets**. Never hardcode them; use `--dart-define` or `flutter_secure_storage`. See [11-credentials-security.md](11-credentials-security.md).

### Fields of `FlutterUmamiConfig`

| Field           | Type               | Default       | Description                                                                                                                                                                                           |
| --------------- | ------------------ | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `websiteId`     | `String`           | required      | Website ID in Umami                                                                                                                                                                                   |
| `endpoint`      | `String`           | required      | Base URL of your Umami instance                                                                                                                                                                       |
| `hostname`      | `String`           | required      | Hostname sent in payloads                                                                                                                                                                             |
| `language`      | `String?`          | system locale | Language override                                                                                                                                                                                     |
| `enabled`       | `bool`             | `true`        | Disables all tracking without modifying calls                                                                                                                                                         |
| `userId`        | `String?`          | `null`        | Stable user identifier across devices                                                                                                                                                                 |
| `ipAddress`     | `String?`          | `null`        | IP override (server-side tracking)                                                                                                                                                                    |
| `queueConfig`   | `UmamiQueueConfig` | `inMemory()`  | Offline queue strategy. Defaults to `UmamiQueueConfig.inMemory(maxSize: kDefaultQueueMaxSize)` (500). See [2-queue.md](2-queue.md).                                                                   |
| `logger`        | `UmamiLogger`      | warning       | Logger configuration. See [8-logging.md](8-logging.md).                                                                                                                                               |
| `firstReferrer` | `String?`          | `null`        | Referrer applied **only to the first `trackPageView`**; it is consumed and cleared. Applied only if that first call does not pass an explicit `referrer` (see `referrer ?? _consumeFirstReferrer()`). |
| `httpTimeout`   | `Duration`         | 5s            | HTTP request timeout                                                                                                                                                                                  |
| `instanceName`  | `String?`          | `null`        | Namespace to isolate storage (multi-instance). See [7-device.md](7-device.md).                                                                                                                        |

## Multiple instances

Create independent instances with their own state, queue, and storage:

```dart
final app = await createUmamiAnalytics(
  const FlutterUmamiConfig(
    websiteId: 'app-site',
    endpoint: 'https://umami.example.com',
    hostname: 'app.example.com',
    instanceName: 'app',
  ),
);

final admin = await createUmamiAnalytics(
  const FlutterUmamiConfig(
    websiteId: 'admin-site',
    endpoint: 'https://umami.example.com',
    hostname: 'admin.example.com',
    instanceName: 'admin',
  ),
);
```

With `instanceName`, storage names are prefixed with its value (see [7-device.md](7-device.md)):

- SQLite: `umami_queue_{instanceName}.db`
- Secure storage: `umami_device_id_{instanceName}`, `umami_first_launch_{instanceName}`

## Lifecycle

Call `dispose()` to release resources:

```dart
await analytics.dispose();
```

`dispose()` is idempotent (`_disposed` flag). The actual cascade:

1. `_collector.dispose()` → `flush()` wrapped in `safeAsync` (errors are only logged, not propagated) → `queue.close()` (only when the collector owns it; injected queues are NOT closed) → `httpClient.dispose()` (only when the collector owns it; injected ports are NOT disposed).
2. In a `finally` block, `apiClient?.dispose()` runs **always**, even if `flush()` threw (and only when the facade owns the api client).

If you want to force-send the queue without destroying the instance, use `flush()`:

```dart
await analytics.flush();
```

`flush()` is reentrant: a `_flushing` flag prevents concurrent executions. When the policy declares a TTL (derived from `PersistedUmamiQueueConfig.eventTtl` by the factory, or set directly on a `TrackingCollector` built by hand), it first purges expired events via `UmamiQueue.deleteExpired`, then sends in parallel with `Future.wait` and deletes only the ones that succeeded.

## Instance properties and methods

```dart
analytics.config      // FlutterUmamiConfig
analytics.collector   // UmamiCollector
analytics.apiClient   // UmamiApiPort? (null if enableApi: false)
analytics.logger      // UmamiLogger (alias of config.logger)
```

Public tracking methods (all return `Future<bool>` and respect `config.enabled`):

- `trackPageView({required url, title?, referrer?, hostname?, language?, screen?, overrides?})` — see [3-tracking.md](3-tracking.md).
- `trackEvent({required name, url?, title?, referrer?, data?, hostname?, language?, screen?, overrides?})` — see [3-tracking.md](3-tracking.md).
- `identify({required properties, sessionId?, overrides?})` — generates a lazy `sessionId` on the first call and reuses it. See [5-identify.md](5-identify.md).
- `flush()` — drains the queue (`Future<void>`).
- `dispose()` — drains, closes, and releases (idempotent).

For direct tracking, lifecycle methods, and a custom collector, see [10-advanced.md](10-advanced.md).
