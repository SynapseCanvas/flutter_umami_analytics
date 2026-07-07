# Inicialización

## `createUmamiAnalytics()`

Crea una instancia de analytics. Llámala antes de cualquier operación de seguimiento.

```dart
final analytics = await createUmamiAnalytics(
  const FlutterUmamiConfig(
    websiteId: 'your-website-id',
    endpoint: 'https://your-umami-instance.com',
    hostname: 'myapp.com',
  ),
);
```

### Parámetros de `createUmamiAnalytics()`

| Parámetro         | Tipo                 | Predeterminado | Descripción                                                                                                                |
| ----------------- | -------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `config`          | `FlutterUmamiConfig` | requerido      | Configuración de la instancia                                                                                              |
| `httpClient`      | `http.Client?`       | `null`         | Cliente HTTP personalizado. Si se pasa, lo comparten `DefaultHttpClient` y `UmamiApiClient`; si no, cada uno crea el suyo. |
| `deviceId`        | `DeviceIdPort?`      | `null`         | Servicio de ID de dispositivo (sólo se construye/usa cuando `recordFirstOpen: true`)                                       |
| `deviceInfo`      | `DeviceInfoPort?`    | `null`         | Servicio de información del dispositivo. Predeterminado: `DefaultDeviceInfoService`.                                       |
| `recordFirstOpen` | `bool`               | `false`        | En la primera ejecución (según `flutter_secure_storage`), envía evento `first_open` con URL `/app/launch`                  |
| `enableApi`       | `bool`               | `false`        | Habilita el cliente REST API (`analytics.apiClient`). Ver [9-api-client.md](9-api-client.md).                              |
| `apiUsername`     | `String?`            | `null`         | Auto-login en `createUmamiAnalytics()` sólo cuando **ambos** `apiUsername` y `apiPassword` están presentes                 |
| `apiPassword`     | `String?`            | `null`         | Contraseña para auto-login. Si el login falla o lanza, `apiClient` queda en `null` (degradación graceful)                  |

> 🔐 **Seguridad**: `apiUsername`/`apiPassword` son **secretos**. Nunca los hardcodes; usa `--dart-define` o `flutter_secure_storage`. Ver [11-credentials-security.md](11-credentials-security.md).

### Campos de `FlutterUmamiConfig`

| Campo           | Tipo               | Predeterminado     | Descripción                                                                                                                                                                                            |
| --------------- | ------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `websiteId`     | `String`           | requerido          | ID del sitio web en Umami                                                                                                                                                                              |
| `endpoint`      | `String`           | requerido          | URL base de tu instancia Umami                                                                                                                                                                         |
| `hostname`      | `String`           | requerido          | Hostname enviado en las cargas útiles                                                                                                                                                                  |
| `language`      | `String?`          | locale del sistema | Anulación de idioma                                                                                                                                                                                    |
| `enabled`       | `bool`             | `true`             | Deshabilita todo el seguimiento sin modificar las llamadas                                                                                                                                             |
| `userId`        | `String?`          | `null`             | Identificador estable de usuario entre dispositivos                                                                                                                                                    |
| `ipAddress`     | `String?`          | `null`             | Anulación de IP (seguimiento en el servidor)                                                                                                                                                           |
| `queueConfig`   | `UmamiQueueConfig` | `inMemory()`       | Estrategia de cola sin conexión. Por defecto `UmamiQueueConfig.inMemory(maxSize: kDefaultQueueMaxSize)` (500). Ver [2-queue.md](2-queue.md).                                                           |
| `logger`        | `UmamiLogger`      | warning            | Configuración del registrador. Ver [8-logging.md](8-logging.md).                                                                                                                                       |
| `firstReferrer` | `String?`          | `null`             | Referrer aplicado **sólo al primer `trackPageView`**; se consume y se limpia. Se aplica únicamente si esa primera llamada no pasa un `referrer` explícito (ver `referrer ?? _consumeFirstReferrer()`). |
| `httpTimeout`   | `Duration`         | 5s                 | Tiempo de espera de las solicitudes HTTP                                                                                                                                                               |
| `instanceName`  | `String?`          | `null`             | Espacio de nombres para aislar almacenamiento (multiinstancia). Ver [7-device.md](7-device.md).                                                                                                        |

## Múltiples instancias

Crea instancias independientes con su propio estado, cola y almacenamiento:

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

Con `instanceName`, los nombres de almacenamiento se prefijan con su valor (ver [7-device.md](7-device.md)):

- SQLite: `umami_queue_{instanceName}.db`
- Secure storage: `umami_device_id_{instanceName}`, `umami_first_launch_{instanceName}`

## Ciclo de vida

Llama `dispose()` para liberar recursos:

```dart
await analytics.dispose();
```

`dispose()` es idempotente (bandera `_disposed`). La cascada real:

1. `_collector.dispose()` → `flush()` envuelto en `safeAsync` (errores sólo se loguean, no propagan) → `queue.close()` (sólo cuando el collector es dueño; las colas inyectadas NO se cierran) → `httpClient.dispose()` (sólo cuando el collector es dueño; los puertos inyectados NO se cierran).
2. En un bloque `finally`, `apiClient?.dispose()` se ejecuta **siempre**, incluso si `flush()` lanzó (y sólo cuando la fachada es dueña del api client).

Si quieres forzar el envío de la cola sin destruir la instancia, usa `flush()`:

```dart
await analytics.flush();
```

`flush()` es reentrante: una bandera `_flushing` evita ejecuciones concurrentes. Cuando la política declara un TTL (derivado del `eventTtl` de `PersistedUmamiQueueConfig` por la factory, o fijado directamente en un `TrackingCollector` construido a mano), primero purga eventos caducados vía `UmamiQueue.deleteExpired`, después envía en paralelo con `Future.wait` y borra sólo los que tuvieron éxito.

## Propiedades y métodos de instancia

```dart
analytics.config      // FlutterUmamiConfig
analytics.collector   // UmamiCollector
analytics.apiClient   // UmamiApiPort? (null si enableApi: false)
analytics.logger      // UmamiLogger (alias de config.logger)
```

Métodos públicos de seguimiento (todos retornan `Future<bool>` y respetan `config.enabled`):

- `trackPageView({required url, title?, referrer?, hostname?, language?, screen?, overrides?})` — ver [3-tracking.md](3-tracking.md).
- `trackEvent({required name, url?, title?, referrer?, data?, hostname?, language?, screen?, overrides?})` — ver [3-tracking.md](3-tracking.md).
- `identify({required properties, sessionId?, overrides?})` — genera un `sessionId` perezoso en la primera llamada y lo reutiliza. Ver [5-identify.md](5-identify.md).
- `flush()` — drena la cola (`Future<void>`).
- `dispose()` — drena, cierra y libera (idempotente).

Para seguimiento directo, métodos de ciclo de vida y collector personalizado, consulta [10-advanced.md](10-advanced.md).
