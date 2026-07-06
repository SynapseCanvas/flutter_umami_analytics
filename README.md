# flutter_umami_analytics

A comprehensive Flutter client for [Umami Analytics](https://umami.is). Track page views, custom events, and user sessions with offline queue support, `NavigatorObserver` auto-tracking, persistent device ID, multi-instance isolation, and optional full REST API access.

## Features

- **Page views & events** — `trackPageView`, `trackEvent`, `identify` with auto-captured device info (locale, screen, User-Agent per platform).
- **Offline queue** — three strategies (`disabled`, `inMemory`, `persisted` SQLite with TTL); auto-flush on next successful send.
- **Persistent device ID** — UUID v4 stored in `flutter_secure_storage`, namespaced per instance.
- **`NavigatorObserver`** — auto-track route pushes/replaces/pops with `routeFilter` and `routeNameMapper` hooks.
- **Multi-instance** — isolated storage and queue per `instanceName`.
- **REST API client** (opt-in) — login, websites, stats, pageviews, metrics, active visitors, events, sessions, teams, users.
- **Per-call overrides** — `websiteId`, `hostname`, `language`, `userId` for a single call without mutating config.
- **Graceful degradation** — every external call is wrapped in `safeAsync`; failures never crash the host app.
- **Configurable logging** — six levels, custom sink callback.
- **Hexagonal architecture** — pure-Dart domain, swappable adapters via `port` interfaces.

## Platforms

Android, iOS, macOS, Windows, Linux. **Web is not supported** (relies on `sqflite` + `flutter_secure_storage`).

## Compatibility

- Dart SDK `^3.4.0`
- Flutter `>=3.22.0`

## Install

```yaml
dependencies:
  flutter_umami_analytics: ^1.0.0
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final analytics = await createUmamiAnalytics(
    const FlutterUmamiConfig(
      websiteId: 'your-website-id',
      endpoint: 'https://your-umami-instance.com',
      hostname: 'myapp.com',
    ),
    recordFirstOpen: true,
  );

  runApp(MyApp(analytics: analytics));
}
```

Track:

```dart
await analytics.trackPageView(url: '/home');

await analytics.trackEvent(
  name: 'button_click',
  data: {'button': 'signup', 'screen': 'home'},
);

await analytics.identify(
  properties: {'tier': 'premium', 'plan': 'enterprise'},
);
```

Auto-track navigation:

```dart
MaterialApp(
  navigatorObservers: [
    UmamiNavigatorObserver(
      collector: analytics.collector,
      autoTrack: true, // default; set false to disable temporarily
      routeFilter: (route) => route.settings.name != '/login',
      routeNameMapper: (route) =>
          route.settings.name != null ? '/app${route.settings.name}' : null,
      logger: analytics.logger, // optional, surfaces track errors
    ),
  ],
)
```

`UmamiNavigatorObserver` listens to `didPush`, `didReplace`, and `didPop` (re-tracking the previous route on pop). When `routeNameMapper` is set, the mapped value is sent as `url` and the original `route.settings.name` as `title`.

Cleanup (flushes queue, closes HTTP & API clients):

```dart
await analytics.dispose();
```

## Configuration

### `FlutterUmamiConfig`

| Parameter       | Type               | Default         | Description                                              |
| --------------- | ------------------ | --------------- | -------------------------------------------------------- |
| `websiteId`     | `String`           | required        | Umami website ID                                         |
| `endpoint`      | `String`           | required        | Umami instance URL                                       |
| `hostname`      | `String`           | required        | Hostname sent in payloads                                |
| `instanceName`  | `String?`          | `null`          | Storage namespace for multi-instance isolation           |
| `language`      | `String?`          | device locale   | Language override                                        |
| `enabled`       | `bool`             | `true`          | Enable/disable all tracking (no-ops all `track*` calls)  |
| `userId`        | `String?`          | `null`          | Stable user identifier sent as payload `id`              |
| `ipAddress`     | `String?`          | `null`          | IP override (server-side tracking, payload `ip_address`) |
| `queueConfig`   | `UmamiQueueConfig` | in-memory (500) | Offline queue strategy                                   |
| `logger`        | `UmamiLogger`      | warning level   | Logger configuration                                     |
| `firstReferrer` | `String?`          | `null`          | One-time referrer consumed by the first `trackPageView`  |
| `httpTimeout`   | `Duration`         | 5s              | HTTP request timeout                                     |

### `createUmamiAnalytics` options

| Parameter         | Type              | Default | Description                                                                                                          |
| ----------------- | ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `httpClient`      | `http.Client?`    | default | Custom HTTP client (timeouts, certs, proxy, cache)                                                                   |
| `deviceId`        | `DeviceIdPort?`   | default | Custom device ID service (only used when `recordFirstOpen`)                                                          |
| `deviceInfo`      | `DeviceInfoPort?` | default | Custom device info provider (locale, screen, UA)                                                                     |
| `recordFirstOpen` | `bool`            | `false` | Send `first_open` event on first launch (persisted flag, URL `/app/launch`)                                          |
| `enableApi`       | `bool`            | `false` | Enable REST API client (`analytics.apiClient`)                                                                       |
| `apiUsername`     | `String?`         | `null`  | Auto-login on init when paired with `apiPassword` (**secret**, see [Credentials & Security](#credentials--security)) |
| `apiPassword`     | `String?`         | `null`  | Password for auto-login (**secret**, see [Credentials & Security](#credentials--security))                           |

## Exposed instance members

```dart
analytics.config      // FlutterUmamiConfig
analytics.collector   // UmamiCollector (for direct/custom tracking)
analytics.apiClient   // UmamiApiPort? (null when enableApi: false)
analytics.logger      // UmamiLogger
```

## Queue

```dart
// Drop events when offline
UmamiQueueConfig.disabled()

// In-memory queue (default, lost on restart)
UmamiQueueConfig.inMemory(maxSize: 500)

// SQLite-persisted queue (survives app restart)
UmamiQueueConfig.persisted(maxSize: 500, eventTtl: Duration(hours: 48))

// Custom SQLite location (default: getDatabasesPath())
UmamiQueueConfig.persisted(
  maxSize: 500,
  eventTtl: Duration(hours: 48),
  databasePath: '/custom/path',
)
```

Events that fail to send are enqueued automatically and flushed on the next successful send (auto-flush). Call `analytics.flush()` to force a flush manually (e.g. on `AppLifecycleState.paused`). `dispose()` always performs a final flush.

`PersistedUmamiQueueConfig` evicts the oldest event when full and prunes entries older than `eventTtl` on every flush. The DB file is `umami_queue_{instanceName}.db` (or `umami_queue.db` when no `instanceName`).

## Logger

```dart
UmamiLogger(
  minLevel: UmamiLogLevel.debug,
  customLogger: (level, msg) => myLoggingService.send(level, msg),
)
```

Levels (lowest → highest): `verbose`, `debug`, `info`, `warning`, `error`, `none`.

## Multi-instance

Independent instances with isolated storage:

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

When `instanceName` is set, storage is namespaced:

- SQLite DB: `umami_queue_{instanceName}.db`
- Secure storage: `umami_device_id_{instanceName}`, `umami_first_launch_{instanceName}`

## REST API client

Enable with `enableApi: true`. Optional auto-login via `apiUsername`/`apiPassword` (login failure returns `null` client, no crash).

```dart
final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: 'admin',
  apiPassword: 'pass',
);

final api = analytics.apiClient;
if (api?.isAuthenticated ?? false) {
  final stats = await api!.getWebsiteStats(
    'website-id',
    startAt: DateTime.now().subtract(const Duration(days: 7)),
    endAt: DateTime.now(),
  );
}
```

Methods on `UmamiApiPort`:

- **Auth**: `login`, `isAuthenticated`
- **Websites**: `getWebsites`, `getWebsite`, `createWebsite`, `updateWebsite`, `deleteWebsite`
- **Stats**: `getWebsiteStats`, `getWebsitePageviews`, `getWebsiteMetrics`, `getWebsiteActiveVisitors`
- **Events & sessions**: `getWebsiteEvents`, `getWebsiteSessions`
- **Teams**: `getTeams`, `createTeam`
- **Users (admin)**: `getAllUsers`, `createUser`, `deleteUser`

`analytics.dispose()` closes the API client too.

## Credentials & Security

The SDK handles two distinct pipelines with very different security profiles:

| Pipeline       | Endpoint                          | Auth required?   | What you provide                                |
| -------------- | --------------------------------- | ---------------- | ----------------------------------------------- |
| **Tracking**   | `POST /api/send`                  | ❌ **Anonymous** | `websiteId` + `endpoint` only                   |
| **REST admin** | `/api/websites/*`, `/api/admin/*` | ✅ Admin session | `apiUsername` + `apiPassword` → JWT (in-memory) |

**Key facts:**

- **No static API keys.** Umami v2 does not issue them. The REST admin flow is `username + password → login() → JWT`.
- **Credentials are never persisted** by the SDK — neither to disk, SQLite, nor `flutter_secure_storage`. The JWT lives in RAM only and is discarded on `dispose()`.
- **Tracking is anonymous.** `trackPageView`, `trackEvent`, `identify`, and `NavigatorObserver` do **not** require any credentials.
- `userId` and `ipAddress` are **tracking parameters**, not credentials.

**Do not hardcode secrets.** Use `--dart-define` or `flutter_secure storage`:

```dart
final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: const String.fromEnvironment('UMAMI_API_USER'),
  apiPassword: const String.fromEnvironment('UMAMI_API_PASS'),
);
```

Quick production checklist:

- [ ] No `apiUsername`/`apiPassword` literals in `lib/`
- [ ] `.env` and secret files in `.gitignore`
- [ ] `endpoint` is `https://`
- [ ] `logger.minLevel` is **not** `verbose` in production (would leak payloads)

Full guide: [`doc/en/11-credentials-security.md`](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/11-credentials-security.md) (or [`doc/es/11-credentials-security.md`](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/11-credentials-security.md)).

## Per-call overrides

Every tracking method accepts an `overrides` map merged into the config for that single call:

```dart
analytics.trackPageView(
  url: '/home',
  overrides: {'hostname': 'different.com'},
);
```

Supported override keys (non-string values are silently ignored):

- `websiteId`
- `hostname`
- `language`
- `userId`

Other config fields (`endpoint`, `enabled`, `queueConfig`, `logger`, `firstReferrer`, `httpTimeout`, `instanceName`, `ipAddress`) cannot be overridden per-call.

## Architecture

Hexagonal (ports & adapters). The `domain/` layer is pure Dart with no Flutter, `http`, `sqflite`, or `flutter_secure_storage` imports — dependencies point inward only. The facade `FlutterUmamiAnalytics` delegates to `TrackingCollector`; `createUmamiAnalytics()` wires default adapters but every port (`UmamiCollector`, `HttpClientPort`, `UmamiQueue`, `DeviceInfoPort`, `DeviceIdPort`, `UmamiApiPort`) is replaceable.

Full diagrams (component graph, tracking flow, queue state machine, dependency graph) in [`doc/architecture.md`](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/architecture.md).

## Documentation

Detailed guides available in **English** and **Spanish**.

### English

Guides in [`doc/en/`](https://github.com/SynapseCanvas/flutter_umami_analytics/tree/main/doc/en):

- [Initialization](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/1-initialization.md) — `createUmamiAnalytics()`, `FlutterUmamiConfig`, multi-instance, lifecycle.
- [Offline Queue](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/2-queue.md) — strategies (`disabled`, `inMemory`, `persisted`), auto-flush, manual flush.
- [Tracking](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/3-tracking.md) — `trackPageView` and `trackEvent`, parameters, automatic payload.
- [NavigatorObserver](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/4-observer.md) — `UmamiNavigatorObserver` for automatic navigation tracking.
- [Session Identification](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/5-identify.md) — `identify()`, lazy `sessionId` management.
- [Overrides](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/6-overrides.md) — per-call `overrides`, `firstReferrer`, `ipAddress`.
- [Device](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/7-device.md) — persistent device ID, device info, per-platform User-Agent.
- [Logging](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/8-logging.md) — `UmamiLogger`, levels, custom sink callback.
- [REST API Client](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/9-api-client.md) — REST client to query Umami.
- [Advanced](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/10-advanced.md) — `first_open` event, custom collector, custom HTTP client, exposed members.
- [Credentials & Security](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/en/11-credentials-security.md) — secrets table, JWT flow, hardening checklist.
- [Architecture](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/architecture.md) — hexagonal architecture diagrams, tracking flow, queue state machine.

### Español

Guías detalladas en [`doc/es/`](https://github.com/SynapseCanvas/flutter_umami_analytics/tree/main/doc/es):

- [Inicialización](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/1-initialization.md) — `createUmamiAnalytics()`, `FlutterUmamiConfig`, multiinstancia, ciclo de vida.
- [Cola](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/2-queue.md) — estrategias (`disabled`, `inMemory`, `persisted`), vaciado automático, vaciado manual.
- [Seguimiento](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/3-tracking.md) — `trackPageView` y `trackEvent`, parámetros, carga útil automática.
- [Observador](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/4-observer.md) — `UmamiNavigatorObserver` para seguimiento automático de navegación.
- [Identificar](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/5-identify.md) — `identify()`, gestión lazy de `sessionId`.
- [Anulaciones](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/6-overrides.md) — `overrides` por llamada, `firstReferrer`, `ipAddress`.
- [Dispositivo](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/7-device.md) — ID de dispositivo persistente, información del dispositivo, User-Agent por plataforma.
- [Registro](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/8-logging.md) — `UmamiLogger`, niveles, devolución de llamada personalizada.
- [Cliente API](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/9-api-client.md) — cliente REST para consultar Umami.
- [Avanzado](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/10-advanced.md) — evento `first_open`, collector personalizado, cliente HTTP personalizado, componentes expuestos.
- [Credenciales y seguridad](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/es/11-credentials-security.md) — tabla de secretos, flujo del JWT, checklist de endurecimiento.
- [Arquitectura](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/doc/architecture.md) — diagramas de la arquitectura hexagonal, flujo de seguimiento, máquina de estados de la cola.

## Contributing

Fork, branch, add tests, open PR. Before committing, run `dart analyze` and `flutter test` — both must pass clean (`strict-casts` and `strict-inference` are enabled).

## License

MIT — see [LICENSE](https://github.com/SynapseCanvas/flutter_umami_analytics/blob/main/LICENSE).

## Acknowledgments

Built on the work of:

- [`umami_analytics`](https://pub.dev/packages/umami_analytics) — offline queue
- [`umami_flutter`](https://pub.dev/packages/umami_flutter) — device ID
- [`flutter_umami`](https://pub.dev/packages/flutter_umami) — collector interface
- [`flutter_estatisticas`](https://pub.dev/packages/flutter_estatisticas) — REST API coverage
- [`@umami/node`](https://github.com/umami-software/node) — identify/session API
