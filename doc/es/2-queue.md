# Cola Offline

Cuando un evento no puede enviarse (sin conexión, tiempo de espera agotado, error HTTP), se almacena en una cola para reenvío posterior.

La cola sigue el patrón hexagonal del paquete: el puerto `UmamiQueue` (`domain/ports/queue_port.dart`) define la interfaz; tres adaptadores en `infrastructure/queue/` la implementan y `queue_factory.dart` selecciona uno mediante `switch` exhaustivo sobre la `sealed class UmamiQueueConfig`.

## Estrategias

`UmamiQueueConfig` expone tres constructores factory constantes. `maxSize` por defecto es `kDefaultQueueMaxSize` (500).

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

Cola SQLite (`PersistedQueue`, paquete `sqflite`). Sobrevive reinicios. Aplica `eventTtl` (predeterminado `Duration(hours: 48)`) para descartar eventos antiguos.

```dart
queueConfig: const UmamiQueueConfig.persisted(
  maxSize: 500,
  eventTtl: Duration(hours: 48),
),
```

El archivo de base de datos se llama `umami_queue{suffix}.db`, donde `{suffix}` es `_{instanceName}` cuando configuras `instanceName`, o vacío en caso contrario. El parámetro `databasePath` anula el **directorio base** (por defecto `getDatabasesPath()`); no es la ruta completa del archivo — el nombre del `.db` siempre lo controla el SDK.

Internamente usa tabla `queued_events` (columnas `id`, `payload`, `created_at`) con índice `idx_created_at`. La inserción se ejecuta dentro de una transacción que, al alcanzar `maxSize`, expulsa atómicamente los eventos más antiguos antes de insertar el nuevo.

## Comportamiento

1. `trackPageView`, `trackEvent` e `identify` intentan enviar vía HTTP.
2. Si fallan → `_enqueue` serializa el payload a JSON y lo inserta. Con `disabled()` se descarta silenciosamente (`NoopQueue.insert` no hace nada).
3. Si el envío tiene éxito → se ejecuta `_autoFlush()`, que drena la cola pendiente.
4. Si la cola está llena (`length >= maxSize`), se elimina el evento más antiguo antes de insertar.
5. Los fallos internos de cola (inserción, lectura, borrado, envío) se capturan vía `safeBool` / `safeAsync` y sólo se loguean: nunca se propagan al llamador (degradación graceful).

`flush()` y `_autoFlush()` comparten la bandera `_flushing`, lo que los hace reentrantes: las llamadas anidadas o concurrentes se descartan. `_autoFlush()` además cortocircuita cuando `length == 0`.

## Vaciado manual

```dart
await analytics.flush();
```

Envía en paralelo todos los eventos encolados (`Future.wait`) y, al terminar, borra de la cola sólo los que se enviaron con éxito. Útil antes de cerrar la app, al recuperar conectividad, o en tareas en segundo plano (`background fetch`).

> En colas persistidas con `eventTtl`, `flush()` primero purga eventos caducados vía `deleteExpired`. Las estrategias `disabled` e `inMemory` ignoran el TTL durante el vaciado.

## Ver también

- `dispose()` en [1-initialization.md](1-initialization.md) ejecuta `flush()` (envuelto en `safeAsync`) y luego `queue.close()`.
- Diagramas de flujo en [`../architecture.md`](../architecture.md).
