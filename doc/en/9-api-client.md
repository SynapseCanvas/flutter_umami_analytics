# REST API Client

Optional client for querying the admin/analytics endpoints of your Umami v2 instance (`/api/websites/*` and `/api/admin/*`). Distinct from the tracking pipeline (`/api/send`): this client is for management and querying.

It implements the `UmamiApiPort` (`domain` layer). The default implementation is `UmamiApiClient` (`infrastructure` layer), built by [createUmamiAnalytics()].

> 🔐 Requires **Umami admin credentials** (exchanged for an in-memory JWT). Read [11-credentials-security.md](11-credentials-security.md) before integrating.

## Enabling

```dart
final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: 'admin',
  apiPassword: 'secret',
);
```

Behavior of `enableApi` in [createUmamiAnalytics()]:

| Credentials (`apiUsername` + `apiPassword`) | Result                                                                                                                               |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Both present                                | `login()` is called automatically. If it fails or throws, `analytics.apiClient` remains `null` (graceful degradation, no exception). |
| Either missing                              | The client is returned **unauthenticated**; `isAuthenticated` will be `false`. You must call `login()` manually.                     |
| `enableApi: false` (default)                | `analytics.apiClient` is `null`.                                                                                                     |

[createUmamiAnalytics()]: 1-initialization.md

## Accessing the client

```dart
final api = analytics.apiClient; // UmamiApiPort?
if (api == null) {
  // enableApi: false, or auto-login failed.
  return;
}
print(api.isAuthenticated); // bool
```

To log in manually (for example, if you omitted credentials or the token expired):

```dart
final loggedIn = await api.login('username', 'password'); // Future<bool>
```

`login()` returns `true` on success and `false` on invalid credentials or transport failure. Subsequent operations require an authenticated session; otherwise a warning is logged and they return `null`/`false`.

## Return convention

All methods are async. Two conventions from the port:

- `null` → the upstream responded but there is no useful body (typically 404 or an empty list).
- `false` → HTTP/transport failure, or upstream not authenticated.

Lists (`getWebsites`, `getWebsiteEvents`, etc.) are wrapped in `List.unmodifiable`: they are read-only.

## Methods

### Websites

```dart
final websites = await api.getWebsites();          // List<Map<String, dynamic>>?
final site    = await api.getWebsite('id');        // Map<String, dynamic>?
final created = await api.createWebsite({          // Map<String, dynamic>?
  'name': 'My Site',
  'domain': 'example.com',
});
final updated = await api.updateWebsite('id', {    // bool
  'name': 'Updated',
});
final deleted = await api.deleteWebsite('id');     // bool
```

### Stats

```dart
final now      = DateTime.now();
final weekAgo  = now.subtract(const Duration(days: 7));

final stats = await api.getWebsiteStats(           // Map<String, dynamic>>?
  'id',
  startAt: weekAgo, // DateTime required (ms-epoch to the backend)
  endAt: now,
);
final pageviews = await api.getWebsitePageviews(   // Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
  unit: 'day',      // optional
  timezone: 'UTC',  // optional
);
final metrics = await api.getWebsiteMetrics(       // Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
  type: 'url',      // required
  limit: 10,        // optional
);
final active = await api.getWebsiteActiveVisitors('id'); // int?
```

### Events and Sessions

```dart
final events   = await api.getWebsiteEvents(       // List<Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
  unit: 'day',
  timezone: 'UTC',
);
final sessions = await api.getWebsiteSessions(      // List<Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
);
```

### Teams and Users

```dart
final teams = await api.getTeams();                // List<Map<String, dynamic>>?
final team  = await api.createTeam({'name': 'X'}); // Map<String, dynamic>?

final users = await api.getAllUsers();             // List<Map<String, dynamic>>?
final user  = await api.createUser({               // Map<String, dynamic>?
  'username': 'new',
  'password': 'pass',
});
final ok = await api.deleteUser('user-id');        // bool
```

## Lifecycle

Do not call `apiClient!.dispose()` directly: [`analytics.dispose()`] closes it automatically in a cascade inside a `finally`, even if the collector flush throws. See [1-initialization.md].

```dart
await analytics.dispose();
// → collector.dispose() (flush + queue.close + httpClient.dispose)
// → apiClient?.dispose()  (always, in finally)
```

`UmamiApiClient` is single-use: after `dispose()`, any subsequent call is logged as a warning and returns `null`/`false`.

## Port substitution

`analytics.apiClient` is typed as `UmamiApiPort?` (abstract). You can inject your own implementation by building the facade manually:

```dart
final analytics = FlutterUmamiAnalytics(
  config: config,
  collector: myCollector,
  apiClient: MyCustomApiPort(),
);
```

Useful for tests (in-memory fakes) or to target an alternative backend. For full assembly with real adapters, keep using [createUmamiAnalytics()].

[1-initialization.md]: 1-initialization.md
