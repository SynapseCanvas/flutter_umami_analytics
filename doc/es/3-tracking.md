# Seguimiento

Los métodos `trackPageView` y `trackEvent` registran, respectivamente, visitas a página y eventos personalizados. Ambos retornan `Future<bool>` y respetan `FlutterUmamiConfig.enabled` (ver [1-initialization.md](1-initialization.md)).

## `trackPageView()`

Registra una visita a una página o pantalla.

```dart
await analytics.trackPageView(
  url: '/home',
  title: 'Home Screen',
  referrer: 'https://google.com',
);
```

### Parámetros

| Parámetro   | Tipo                    | Requerido | Descripción                                                                                                                                                                                      |
| ----------- | ----------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `url`       | `String`                | sí        | URL/ruta de la página                                                                                                                                                                            |
| `title`     | `String?`               | no        | Título de la página                                                                                                                                                                              |
| `referrer`  | `String?`               | no        | URL de referencia. Tiene prioridad sobre `firstReferrer`; si se pasa, `firstReferrer` **no** se consume y queda pendiente para la siguiente página vista (ver [6-overrides.md](6-overrides.md)). |
| `hostname`  | `String?`               | no        | Anulación de hostname                                                                                                                                                                            |
| `language`  | `String?`               | no        | Anulación de idioma                                                                                                                                                                              |
| `screen`    | `String?`               | no        | Anulación de resolución (predeterminada: resolución del dispositivo. Ver [7-device.md](7-device.md))                                                                                             |
| `overrides` | `Map<String, dynamic>?` | no        | Anulaciones por llamada (ver [6-overrides.md](6-overrides.md))                                                                                                                                   |

## `trackEvent()`

Registra un evento personalizado con datos opcionales.

```dart
await analytics.trackEvent(
  name: 'purchase',
  url: '/checkout',
  data: {'product': 'premium', 'amount': 19.99},
);
```

### Parámetros

| Parámetro   | Tipo                    | Requerido | Descripción                             |
| ----------- | ----------------------- | --------- | --------------------------------------- |
| `name`      | `String`                | sí        | Nombre del evento                       |
| `url`       | `String?`               | no        | URL asociada (predeterminado: `/event`) |
| `title`     | `String?`               | no        | Título de la página                     |
| `referrer`  | `String?`               | no        | URL de referencia                       |
| `data`      | `Map<String, dynamic>?` | no        | Datos adicionales del evento            |
| `hostname`  | `String?`               | no        | Anulación de hostname                   |
| `language`  | `String?`               | no        | Anulación de idioma                     |
| `screen`    | `String?`               | no        | Anulación de resolución                 |
| `overrides` | `Map<String, dynamic>?` | no        | Anulaciones por llamada                 |

## Valor de retorno

Ambos métodos retornan `Future<bool>`:

| Valor   | Significado                                                                                                                       |
| ------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `true`  | El evento se envió correctamente al endpoint `/api/send`. Si la cola tenía eventos pendientes, se ejecuta `_autoFlush()`.         |
| `false` | `FlutterUmamiConfig.enabled` es `false` **o** el envío falló y el evento se encoló (o descartó si `queueConfig` es `disabled()`). |

## `enabled: false`

Con `enabled: false` en `FlutterUmamiConfig`, la fachada `FlutterUmamiAnalytics` retorna `false` inmediatamente sin delegar al collector, sin enviar nada y sin encolar. Útil para desactivar el seguimiento en debug sin tocar las llamadas.

## Carga útil automática

El collector construye un `UmamiPayload` con estos campos rellenados automáticamente cuando no se pasan explícitamente:

- `website` — `FlutterUmamiConfig.websiteId`.
- `hostname` — `FlutterUmamiConfig.hostname`.
- `language` — `FlutterUmamiConfig.language` o, si es `null`, el locale del dispositivo. Ver [7-device.md](7-device.md).
- `screen` — resolución del dispositivo. Ver [7-device.md](7-device.md).
- `ip_address` — sólo si se configuró `FlutterUmamiConfig.ipAddress`. Ver [6-overrides.md](6-overrides.md).
- `id` — `FlutterUmamiConfig.userId` si está configurado; si no, el `sessionId` lazily generado por [`identify()`](5-identify.md). Si ninguno aplica, se omite.
- `referrer` — ver consumo de `firstReferrer` más abajo.

El campo `data` de `trackEvent` sólo se serializa cuando es no `null` **y** no vacío (`data.isNotEmpty`).

### First-Referrer

`FlutterUmamiConfig.firstReferrer` se consume una sola vez: se adjunta como `referrer` al primer `trackPageView` que **no** reciba un `referrer` explícito, y luego se descarta. `trackEvent` no lo consume. Ver detalles en [6-overrides.md](6-overrides.md).

## Comportamiento de envío

1. El collector invoca `_send`, que realiza la petición HTTP al endpoint `/api/send` (ver [1-initialization.md](1-initialization.md) para `httpTimeout`).
2. Si la petición falla (sin conexión, timeout, error HTTP), el payload se serializa a JSON (`jsonEncode`) y se inserta en la cola — salvo si `queueConfig` es `disabled()`, en cuyo caso se descarta. Ver [2-queue.md](2-queue.md).
3. Si la petición tiene éxito, se ejecuta `_autoFlush()` para drenar la cola pendiente. `flush()` y `_autoFlush()` comparten la bandera `_flushing` (reentrante).

> Los fallos internos del HTTP y de la cola se capturan vía `safeBool` / `safeAsync` y sólo se loguean: nunca se propagan al llamador (degradación graceful).
