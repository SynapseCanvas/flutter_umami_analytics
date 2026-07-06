# Identificación de Sesión

## `identify()`

Asocia propiedades a una sesión de usuario.

```dart
await analytics.identify(
  properties: {'tier': 'premium', 'plan': 'enterprise'},
  sessionId: 'custom-session-123',
);
```

### Parámetros

| Parámetro    | Tipo                    | Requerido | Descripción                                                                     |
| ------------ | ----------------------- | --------- | ------------------------------------------------------------------------------- |
| `properties` | `Map<String, dynamic>`  | sí        | Propiedades a asociar con la sesión                                             |
| `sessionId`  | `String?`               | no        | ID de sesión personalizado (generado automáticamente si es `null`)              |
| `overrides`  | `Map<String, dynamic>?` | no        | Anulaciones de configuración por llamada (ver [6-overrides.md](6-overrides.md)) |

### Comportamiento

- La primera llamada genera un `sessionId` UUID v4 si no se proporciona.
- Si se pasa `sessionId` en la primera llamada, se usa ese valor para todo el ciclo de vida del collector (el primer valor persiste). Para una sesión diferente, crea una instancia nueva con `createUmamiAnalytics()`.
- El `sessionId` se incluye como `id` en `trackPageView`/`trackEvent` posteriores, salvo que se haya configurado `userId` en `FlutterUmamiConfig` (prioridad).
- Si el envío falla y hay cola activa, se encola para reenvío. Ver [2-queue.md](2-queue.md).

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

### Carga útil generada

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
