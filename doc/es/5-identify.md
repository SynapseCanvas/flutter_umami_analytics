# Identificación de Sesión

Asocia propiedades arbitrarias a la sesión del usuario y genera (lazy) el `sessionId` que luego reutilizan `trackPageView`/`trackEvent`. Retorna `Future<bool>` y respeta `FlutterUmamiConfig.enabled` (ver [1-initialization.md](1-initialization.md)).

## `identify()`

```dart
await analytics.identify(
  properties: {'tier': 'premium', 'plan': 'enterprise'},
  sessionId: 'custom-session-123',
);
```

### Parámetros

| Parámetro    | Tipo                    | Requerido | Descripción                                                                     |
| ------------ | ----------------------- | --------- | ------------------------------------------------------------------------------- |
| `properties` | `Map<String, dynamic>`  | sí        | Atributos a asociar con la sesión. Se serializan en `payload.data`.             |
| `sessionId`  | `String?`               | no        | ID de sesión personalizado. Ignorado si ya existía uno previo (ver abajo).      |
| `overrides`  | `Map<String, dynamic>?` | no        | Anulaciones de configuración por llamada (ver [6-overrides.md](6-overrides.md)) |

### Ciclo de vida del `sessionId`

La resolución sigue `_sessionId ?? sessionId ?? _newSessionId()` en `TrackingCollector.identify`:

1. Si `_sessionId` ya está fijado (por una llamada previa), **se ignora** el `sessionId` pasado y se reutiliza el existente. El primer valor persiste durante toda la vida del collector.
2. Si `_sessionId` es `null` y se pasa `sessionId`, se usa ese valor y se almacena en `_sessionId`.
3. Si `_sessionId` es `null` y no se pasa `sessionId`, se genera un UUID v4 nuevo vía `uuid` (`_uuid.v4()`).

Para iniciar una sesión distinta, crea una instancia nueva con `createUmamiAnalytics()` (no hay API para resetear el `sessionId` en caliente).

El `sessionId` (almacenado en `_sessionId`) se propaga como `id` en los `UmamiPayload` posteriores de `trackPageView`/`trackEvent`, con prioridad: `FlutterUmamiConfig.userId ?? _sessionId`. Si ninguno está fijado, el campo `id` se omite del payload.

### Envío y cola

El payload se envía por el mismo camino que `trackPageView`/`trackEvent` (`_send` → endpoint `/api/send`). Si la petición falla y la cola está activa, se encola para reenvío; si `queueConfig` es `disabled()`, se descarta. Ver [2-queue.md](2-queue.md) y [3-tracking.md](3-tracking.md#comportamiento-de-envío).

### Ejemplo con login

```dart
Future<void> onUserLogin(User user) async {
  await analytics.identify(
    properties: {
      'userId': user.id,
      'email': user.email,
      'tier': user.subscriptionTier,
    },
  );
}
```

### Valor de retorno

Retorna `Future<bool>`:

| Valor   | Significado                                                                                                                               |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `false` | `FlutterUmamiConfig.enabled` es `false` (la fachada retorna sin delegar), **o** el envío falló y el evento se encoló/descartó según cola. |
| `true`  | El identify se envió correctamente al endpoint `/api/send`.                                                                               |

### Carga útil generada

`UmamiIdentifyPayload.toJson()` envuelve el cuerpo bajo `{type, payload}`. El campo `data` **sólo** se serializa cuando `properties` es no `null` **y** no vacío (`data.isNotEmpty`); en caso contrario se omite.

```json
{
  "type": "identify",
  "payload": {
    "website": "your-website-id",
    "sessionId": "4b6f1c3a-9d2e-4a8b-b7c5-1f3e9a0d2c4e",
    "data": {
      "userId": "usr_abc123",
      "email": "user@example.com",
      "tier": "premium"
    }
  }
}
```
