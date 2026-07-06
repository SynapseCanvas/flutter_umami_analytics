# Cliente REST API

Cliente opcional para consultar datos de tu instancia Umami. Se activa con `enableApi: true`.

## Habilitación

```dart
final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: 'admin',
  apiPassword: 'secret',
);
```

Si pasas `apiUsername` y `apiPassword`, se inicia sesión automáticamente durante `createUmamiAnalytics()`. Si el login falla, `analytics.apiClient` queda `null` (sin excepción).

```dart
final api = analytics.apiClient;
print(api?.isAuthenticated); // true
```

También puedes iniciar sesión manualmente:

```dart
final loggedIn = await api!.login('username', 'password');
```

## Métodos

### Websites

```dart
final websites = await api.getWebsites();
final site = await api.getWebsite('website-id');
final created = await api.createWebsite({'name': 'My Site', 'domain': 'example.com'});
final ok = await api.updateWebsite('id', {'name': 'Updated'});
final deleted = await api.deleteWebsite('id');
```

### Stats

```dart
final now = DateTime.now();
final weekAgo = now.subtract(const Duration(days: 7));

final stats = await api.getWebsiteStats('id', startAt: weekAgo, endAt: now);
final pageviews = await api.getWebsitePageviews(
  'id',
  startAt: weekAgo,
  endAt: now,
  unit: 'day',
);
final metrics = await api.getWebsiteMetrics(
  'id',
  startAt: weekAgo,
  endAt: now,
  type: 'url',
  limit: 10,
);
final active = await api.getWebsiteActiveVisitors('id');
```

### Events y Sessions

```dart
final events = await api.getWebsiteEvents(
  'id',
  startAt: weekAgo,
  endAt: now,
);
final sessions = await api.getWebsiteSessions(
  'id',
  startAt: weekAgo,
  endAt: now,
);
```

### Teams y Users

```dart
final teams = await api.getTeams();
final team = await api.createTeam({'name': 'My Team'});

final users = await api.getAllUsers();
final user = await api.createUser({'username': 'new', 'password': 'pass'});
final ok = await api.deleteUser('user-id');
```

`analytics.dispose()` cierra el cliente API. Ver [1-initialization.md](1-initialization.md).
