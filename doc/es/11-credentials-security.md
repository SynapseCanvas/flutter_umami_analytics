# Credenciales y seguridad

Resumen centralizado de los recursos sensibles (y no sensibles) que maneja el SDK, qué habilita cada uno, dónde vive y cómo tratarlo. Lee esto antes de pasar credenciales en código versionado.

## TL;DR

- El SDK **no usa API keys estáticas ni tokens preemitidos**.
- El **tracking** (`/api/send`) es **anónimo** en Umami v2: solo necesita `websiteId` + `endpoint`. Sin auth.
- El **REST API client** (`/api/websites/*`, `/api/admin/*`) requiere **auth admin** (`username` + `password`), que se intercambia por un **JWT en memoria** tras `login()`.
- Las credenciales admin **nunca se persisten** dentro del SDK; el JWT vive solo en RAM y se pierde al `dispose()`.
- **Nunca** hardcodees `apiUsername`/`apiPassword`: usa `--dart-define`, variables de entorno o `flutter_secure_storage`.

## Recursos que maneja el SDK

| Recurso        | ¿Secreto?    | Requerido para                         | Origen / destino                                                                        |
| -------------- | ------------ | -------------------------------------- | --------------------------------------------------------------------------------------- |
| `websiteId`    | ❌ No        | Tracking — siempre                     | Panel admin de Umami → `FlutterUmamiConfig`                                             |
| `endpoint`     | ❌ No        | Todo — siempre                         | URL pública de tu instancia Umami → `FlutterUmamiConfig`                                |
| `hostname`     | ❌ No        | Tracking — siempre                     | Hostname reportado en payloads → `FlutterUmamiConfig`                                   |
| `apiUsername`  | ✅ Sí        | REST admin (cuando `enableApi: true`)  | Parámetro de `createUmamiAnalytics()` → no se persiste                                  |
| `apiPassword`  | ✅ Sí        | REST admin (cuando `enableApi: true`)  | Parámetro de `createUmamiAnalytics()` → no se persiste                                  |
| JWT (interno)  | ✅ Sí        | Sesión REST tras `login()`             | `UmamiApiClient._token` + `_currentHeaders` — **solo en RAM**, se pierde al `dispose()` |
| `userId`       | 🟡 Según uso | Tracking identificado (no es auth)     | `FlutterUmamiConfig` o `overrides` por llamada                                          |
| `ipAddress`    | 🟡 Según uso | Override server-side (no es auth)      | `FlutterUmamiConfig`                                                                    |
| `instanceName` | ❌ No        | Namespacing de SQLite + secure storage | `FlutterUmamiConfig`                                                                    |

## Los dos pipelines

### 1. Tracking (`/api/send`) — anónimo

Umami v2 acepta eventos de tracking **sin autenticación**: el `websiteId` identifica de forma abierta el sitio receptor. El SDK no adjunta `Authorization` en estas llamadas.

Headers enviados (`http_headers.dart:27`):

```
Content-Type: application/json
Accept: application/json
User-Agent: flutter_umami_analytics/<platform>
x-umami-cache: <cache token opcional>     ← mecanismo etag-like de Umami
```

No hay `Authorization`. Por eso **no necesitas credenciales** para usar `trackPageView`, `trackEvent`, `identify`, ni el `NavigatorObserver`.

### 2. REST API client (`/api/websites/*`, `/api/admin/*`) — autenticado

Habilitado con `enableApi: true`. Necesita sesión admin de Umami. Flujo:

1. `login(username, password)` → `POST /api/auth/login` con body JSON.
2. Umami responde `{ "token": "<JWT>" }` (200 OK) o 401 en credenciales inválidas.
3. `UmamiApiClient` almacena el JWT en `_token` y compone headers con `Authorization: Bearer <JWT>` (`http_headers.dart:40`).
4. Toda llamada REST posterior adjunta ese header automáticamente.
5. `dispose()` descarta el JWT de RAM. No hay persistencia, refresh ni cache en disco.

Diagrama del flujo en [`doc/architecture.md`](../architecture.md) (sección API client).

> **Importante**: Umami v2 **no expone API keys estáticas**. La única forma de autenticar el REST admin es username + password → JWT. Si rotas la contraseña, todos los JWTs previos dejan de ser válidos.

## Dónde NO persiste nada el SDK

Aclaremos qué **no** hace el SDK para evitar sorpresas:

- ❌ **No escribe** `apiUsername`/`apiPassword` en disco, SQLite, secure storage ni logs.
- ❌ **No persiste** el JWT. Cada arranque de app hace un nuevo `login()`.
- ❌ **No loguea** el JWT ni las credenciales (sólo warnings de fallo como `"API login failed"`).
- ✅ **Sí persiste** (en `flutter_secure_storage`): el `deviceId` UUID v4 y el flag `first_launch`. No son secretos.

## Buenas prácticas

### 1. Lee credenciales del entorno

```dart
final username = const String.fromEnvironment('UMAMI_API_USER');
final password = const String.fromEnvironment('UMAMI_API_PASS');

final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: username.isEmpty ? null : username,
  apiPassword: password.isEmpty ? null : password,
);
```

Ejecuta con:

```bash
flutter run \
  --dart-define=UMAMI_API_USER=admin \
  --dart-define=UMAMI_API_PASS=secret
```

`--dart-define` queda compilado en el binario, pero al menos separa código de valores y permite múltiples entornos (dev/staging/prod).

### 2. Mejor aún: `flutter_secure_storage` en runtime

Para apps cliente donde no controlas el binario, carga las credenciales desde `flutter_secure_storage` configurado por un canal seguro (p. ej. tras login de tu propio backend):

```dart
const storage = FlutterSecureStorage();
final user = await storage.read(key: 'umami_api_user');
final pass = await storage.read(key: 'umami_api_pass');

final analytics = await createUmamiAnalytics(
  config,
  enableApi: true,
  apiUsername: user,
  apiPassword: pass,
);
```

### 3. No versiones credenciales

- `.env`, `config.json`, `secrets.yaml` → en `.gitignore`.
- Usa ejemplos con placeholders (`'admin'`, `'secret'`) en docs y tests, no valores reales.

### 4. Permisos mínimos en Umami

Crea un usuario Umami con rol **admin** o **user** según necesites. Si solo vas a leer stats, no uses la cuenta owner.

### 5. HTTPS siempre

`endpoint` debe ser `https://`. El JWT viaja en cada request y `login` envía la contraseña en claro en el body JSON — solo aceptable sobre TLS.

## Confusiones comunes

### "¿Necesito un token API para trackear?"

**No.** Tracking es anónimo en Umami v2. Solo necesitas `websiteId` y `endpoint`. Las credenciales son exclusivas del REST admin client.

### "¿Es `userId` una credencial?"

**No.** `userId` en `FlutterUmamiConfig` es un identificador de tracking (se envía como `id` en el payload). Sirve para correlacionar eventos de un mismo usuario entre dispositivos. No autentica nada.

### "¿Y `ipAddress`?"

Tampoco. Es un override del IP reportado al backend, útil para tracking server-side. No es auth.

### "El JWT expiró, ¿qué hago?"

El SDK no maneja expiración automática. Si una llamada REST empieza a fallar con 401, vuelve a llamar `login()`:

```dart
if (!api.isAuthenticated) {
  await api.login(username, password);
}
```

### "¿Puedo inyectar mi propio `UmamiApiPort` ya autenticado?"

Sí. Desde la v1.1.0 puedes pasar `apiClient:` a `createUmamiAnalytics()` con tu propia implementación. Así tú controlas el ciclo de vida del token. Ver [9-api-client.md](9-api-client.md).

## Chequeo rápido de seguridad

Antes de enviar tu app a producción:

- [ ] `apiUsername`/`apiPassword` no están hardcodeados en `lib/`.
- [ ] `.env` o archivos de config con secretos están en `.gitignore`.
- [ ] `endpoint` usa `https://`.
- [ ] `logger.minLevel` no es `verbose` en producción (podría filtrar payloads).
- [ ] Si usas tracking identificado, `userId` no contiene datos personales sensibles (en Umami el `userId` es visible en el panel).
- [ ] Rotaste las credenciales si alguna vez se commitearon por error.

## Ver también

- [1-initialization.md](1-initialization.md) — parámetros completos de `createUmamiAnalytics()`.
- [9-api-client.md](9-api-client.md) — habilitación y lifecycle del REST client.
- [`../architecture.md`](../architecture.md) — diagrama del flujo `login → token`.
