# Cliente REST API

Cliente opcional para consultar endpoints admin/analytics de tu instancia Umami v2 (`/api/websites/*` y `/api/admin/*`). Distinto del pipeline de tracking (`/api/send`): este cliente es de gestión y consulta.

Implementa el port `UmamiApiPort` (capa `domain`). La implementación por defecto es `UmamiApiClient` (capa `infrastructure`), construida por [createUmamiAnalytics()].

## Habilitación

```dart
final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: 'admin',
  apiPassword: 'secret',
);
```

Comportamiento de `enableApi` en [createUmamiAnalytics()]:

| Credenciales (`apiUsername` + `apiPassword`) | Resultado                                                                                                                         |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Ambas presentes                              | Se llama a `login()` automáticamente. Si falla o lanza, `analytics.apiClient` queda `null` (degradación graceful, sin excepción). |
| Alguna ausistente                            | Se devuelve el cliente **sin autenticar**; `isAuthenticated` será `false`. Debes llamar a `login()` manualmente.                  |
| `enableApi: false` (por defecto)             | `analytics.apiClient` es `null`.                                                                                                  |

[createUmamiAnalytics()]: 1-initialization.md

## Acceso al cliente

```dart
final api = analytics.apiClient; // UmamiApiPort?
if (api == null) {
  // enableApi: false, o el auto-login falló.
  return;
}
print(api.isAuthenticated); // bool
```

Para iniciar sesión manualmente (por ejemplo, si omitiste credenciales o el token expiró):

```dart
final loggedIn = await api.login('username', 'password'); // Future<bool>
```

`login()` retorna `true` en éxito y `false` en credenciales inválidas o fallo de transporte. Las operaciones siguientes requieren sesión autenticada; si no, se loguea un warning y retornan `null`/`false`.

## Convención de retornos

Todos los métodos son async. Dos convenios del port:

- `null` → el upstream respondió pero no hay cuerpo útil (típicamente 404 o lista vacía).
- `false` → fallo HTTP/transporte, o upstream no autenticado.

Las listas (`getWebsites`, `getWebsiteEvents`, etc.) vienen envueltas en `List.unmodifiable`: son de sólo lectura.

## Métodos

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
  startAt: weekAgo, // DateTime requerido (ms-epoch al backend)
  endAt: now,
);
final pageviews = await api.getWebsitePageviews(   // Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
  unit: 'day',      // opcional
  timezone: 'UTC',  // opcional
);
final metrics = await api.getWebsiteMetrics(       // Map<String, dynamic>>?
  'id',
  startAt: weekAgo,
  endAt: now,
  type: 'url',      // requerido
  limit: 10,        // opcional
);
final active = await api.getWebsiteActiveVisitors('id'); // int?
```

### Events y Sessions

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

### Teams y Users

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

## Ciclo de vida

No llames a `apiClient!.dispose()` directamente: [`analytics.dispose()`] lo cierra automáticamente en cascada dentro de un `finally`, incluso si el flush del collector lanza. Ver [1-initialization.md].

```dart
await analytics.dispose();
// → collector.dispose() (flush + queue.close + httpClient.dispose)
// → apiClient?.dispose()  (siempre, en finally)
```

`UmamiApiClient` es de un solo uso: tras `dispose()`, cualquier llamada subsiguiente se loguea como warning y retorna `null`/`false`.

## Sustitución del port

`analytics.apiClient` está tipado como `UmamiApiPort?` (abstracto). Puedes inyectar tu propia implementación construyendo el facade manualmente:

```dart
final analytics = FlutterUmamiAnalytics(
  config: config,
  collector: myCollector,
  apiClient: MyCustomApiPort(),
);
```

Útil para tests (fakes en memoria) o para apuntar a un backend alternativo. Para ensamblaje completo con adapters reales, sigue usando [createUmamiAnalytics()].

[1-initialization.md]: 1-initialization.md
