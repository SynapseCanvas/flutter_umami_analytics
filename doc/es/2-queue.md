# Cola Offline

Cuando un evento no puede enviarse (sin conexión, tiempo de espera agotado, error HTTP, o cualquier `false` devuelto por el cliente HTTP), se almacena en una cola para reenvío posterior.

La cola sigue el patrón hexagonal del paquete: el puerto `UmamiQueue` (`domain/ports/queue_port.dart`) define la interfaz; tres adaptadores en `infrastructure/queue/` la implementan y `queue_factory.dart` selecciona uno mediante `switch` exhaustivo sobre la `sealed class UmamiQueueConfig`.

## Estrategias

`UmamiQueueConfig` expone tres constructores factory `const`. `maxSize` por defecto es `kDefaultQueueMaxSize` (500).

### `UmamiQueueConfig.disabled()`

Sin cola (`NoopQueue`). Los eventos que fallan se descartan.

```dart
queueConfig: const UmamiQueueConfig.disabled(),
```

### `UmamiQueueConfig.inMemory({maxSize})`

Cola en memoria (`InMemoryQueue`, basada en `LinkedHashMap`). Se pierde al cerrar la app.

```dart
queueConfig: const UmamiQueueConfig.inMemory(maxSize: 500),
```

### `UmamiQueueConfig.persisted({maxSize, eventTtl, databasePath})`

Cola SQLite (`PersistedQueue`, paquete `sqflite`). Sobrevive reinicios. Aplica `eventTtl` (predeterminado `Duration(hours: 48)`) para descartar eventos antiguos durante el vaciado.

```dart
queueConfig: const UmamiQueueConfig.persisted(
  maxSize: 500,
  eventTtl: Duration(hours: 48),
),
```

El archivo de base de datos se llama `umami_queue.db` o `umami_queue_{instanceName}.db` cuando configuras `instanceName` (multiinstancia). El parámetro `databasePath` anula el **directorio base** (por defecto `getDatabasesPath()`); no es la ruta completa del archivo — el nombre del `.db` siempre lo controla el SDK vía `instanceSuffix(instanceName)`.

Internamente usa tabla `queued_events` (columnas `id INTEGER PRIMARY KEY AUTOINCREMENT`, `payload TEXT NOT NULL`, `created_at INTEGER NOT NULL`) con índice `idx_created_at`. La inserción se ejecuta dentro de una transacción que, al alcanzar `maxSize`, expulsa atómicamente los eventos más antiguos (`count - maxSize + 1` filas) antes de insertar el nuevo, manteniendo el límite.

## Puerto `UmamiQueue`

Contrato que implementan los tres adaptadores:

| Método               | Retorno                     | Descripción                                                                        |
| -------------------- | --------------------------- | ---------------------------------------------------------------------------------- |
| `insert(payload)`    | `Future<void>`              | Añade un payload JSON opaco (salida de `UmamiPayload.toJson`).                     |
| `getAll()`           | `Future<List<QueuedEvent>>` | Lee los eventos en orden de inserción (`id ASC`).                                  |
| `delete(id)`         | `Future<void>`              | Borra un evento por id de fila tras un envío exitoso. No-op si el id no existe.    |
| `deleteExpired(ttl)` | `Future<void>`              | Purga eventos con `created_at` anterior a `now - ttl`.                             |
| `length`             | `Future<int>`               | Profundidad actual (snapshot best-effort).                                         |
| `close()`            | `Future<void>`              | Libera recursos (cierra la BD en `PersistedQueue`, limpia map en `InMemoryQueue`). |

El modelo de fila es `QueuedEvent` (`domain/models/queued_event.dart`): `{id?, payload, createdAt}`. `id` es `null` en memoria y en eventos no insertados; lo asigna SQLite sólo en la cola persistida.

## Comportamiento

1. `trackPageView`, `trackEvent` e `identify` construyen su `UmamiPayload` y lo pasan a `_send`.
2. `_send` intenta el envío vía HTTP. Si falla → `_enqueue` serializa el payload a JSON (`jsonEncode`) y lo inserta. Con `disabled()`, `_enqueue` cortocircuita con un `return` temprano al detectar `DisabledUmamiQueueConfig` — el evento se descarta sin llegar a tocar la cola (la propia `NoopQueue.insert` también es no-op, pero no se alcanza).
3. Si el envío tiene éxito → se ejecuta `_autoFlush()`, que drena la cola pendiente (ver más abajo).
4. Si la cola está llena (`length >= maxSize`), se eliminan los eventos más antiguos **antes** de insertar:
   - `InMemoryQueue`: bucle `while` que retira entradas hasta quedar por debajo de `maxSize`.
   - `PersistedQueue`: transacción que borra `count - maxSize + 1` filas (normalmente 1; más sólo si el count excede el límite).
5. Los fallos internos de cola (inserción, lectura, borrado, envío) se capturan vía `safeBool` / `safeAsync` y sólo se loguean: nunca se propagan al llamador (degradación graceful).

`flush()` y `_autoFlush()` comparten la bandera `_flushing`, lo que los hace reentrantes: las llamadas anidadas o concurrentes se descartan con `return` inmediato. `_autoFlush()` además cortocircuita cuando `length == 0` (lectura previa al envío) y reutiliza el mismo `_doFlush()` que `flush()`.

## Vaciado manual

```dart
await analytics.flush();
```

`_doFlush()` envía en paralelo todos los eventos encolados (`Future.wait` sobre `_flushOne`) y, al terminar, borra de la cola sólo los que se enviaron con éxito. Útil antes de cerrar la app, al recuperar conectividad, o en tareas en segundo plano (`background fetch`).

Resiliencia extra: si un payload encolado no se puede decodificar como JSON (`QueuedEvent.decodedPayload == null`, p.ej. fila corrupta), `_flushOne` lo borra directamente y devuelve `false` — no se reintenta indefinidamente.

> La purga TTL durante el vaciado sólo aplica a `UmamiQueueConfig.persisted()`: `_doFlush` hace `switch` sobre la config y llama a `deleteExpired(eventTtl)` únicamente para `PersistedUmamiQueueConfig`, ya que `eventTtl` vive exclusivamente en esa variante. Las estrategias `disabled` e `inMemory` ignoran el TTL durante el vaciado.

## Ver también

- `dispose()` en [1-initialization.md](1-initialization.md) ejecuta `flush()` (envuelto en `safeAsync`) y luego `queue.close()`.
- Multiinstancia y namespaces de almacenamiento en [1-initialization.md](1-initialization.md#múltiples-instancias) y [7-device.md](7-device.md).
- Diagramas de flujo en [`../architecture.md`](../architecture.md).
