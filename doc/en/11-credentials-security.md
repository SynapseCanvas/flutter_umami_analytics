# Credentials & Security

Centralized reference of the sensitive (and non-sensitive) resources the SDK handles, what each one unlocks, where it lives, and how to treat it. Read this before passing any credentials into version-controlled code.

## TL;DR

- The SDK **does not use static API keys or pre-issued tokens**.
- **Tracking** (`/api/send`) is **anonymous** in Umami v2: only `websiteId` + `endpoint` required. No auth.
- The **REST API client** (`/api/websites/*`, `/api/admin/*`) requires **admin credentials** (`username` + `password`), which are exchanged for an **in-memory JWT** after `login()`.
- Admin credentials are **never persisted** inside the SDK; the JWT lives in RAM only and is discarded on `dispose()`.
- **Never** hardcode `apiUsername`/`apiPassword`: use `--dart-define`, environment variables, or `flutter_secure_storage`.

## Resources the SDK handles

| Resource       | Secret?    | Required for                           | Source / destination                                                                 |
| -------------- | ---------- | -------------------------------------- | ------------------------------------------------------------------------------------ |
| `websiteId`    | ❌ No      | Tracking — always                      | Umami admin panel → `FlutterUmamiConfig`                                             |
| `endpoint`     | ❌ No      | Everything — always                    | Public URL of your Umami instance → `FlutterUmamiConfig`                             |
| `hostname`     | ❌ No      | Tracking — always                      | Hostname reported in payloads → `FlutterUmamiConfig`                                 |
| `apiUsername`  | ✅ Yes     | REST admin (when `enableApi: true`)    | Parameter of `createUmamiAnalytics()` → not persisted                                |
| `apiPassword`  | ✅ Yes     | REST admin (when `enableApi: true`)    | Parameter of `createUmamiAnalytics()` → not persisted                                |
| JWT (internal) | ✅ Yes     | REST session after `login()`           | `UmamiApiClient._token` + `_currentHeaders` — **RAM only**, discarded on `dispose()` |
| `userId`       | 🟡 Depends | Identified tracking (not auth)         | `FlutterUmamiConfig` or per-call `overrides`                                         |
| `ipAddress`    | 🟡 Depends | Server-side override (not auth)        | `FlutterUmamiConfig`                                                                 |
| `instanceName` | ❌ No      | Namespacing of SQLite + secure storage | `FlutterUmamiConfig`                                                                 |

## The two pipelines

### 1. Tracking (`/api/send`) — anonymous

Umami v2 accepts tracking events **without authentication**: the `websiteId` openly identifies the destination site. The SDK does not attach an `Authorization` header to these calls.

Headers sent (`http_headers.dart:27`):

```
Content-Type: application/json
Accept: application/json
User-Agent: flutter_umami_analytics/<platform>
x-umami-cache: <optional cache token>     ← Umami's etag-like mechanism
```

No `Authorization`. That's why you **do not need any credentials** to use `trackPageView`, `trackEvent`, `identify`, or the `NavigatorObserver`.

### 2. REST API client (`/api/websites/*`, `/api/admin/*`) — authenticated

Enabled with `enableApi: true`. Requires an Umami admin session. Flow:

1. `login(username, password)` → `POST /api/auth/login` with a JSON body.
2. Umami responds with `{ "token": "<JWT>" }` (200 OK) or 401 on invalid credentials.
3. `UmamiApiClient` stores the JWT in `_token` and composes headers with `Authorization: Bearer <JWT>` (`http_headers.dart:40`).
4. Every subsequent REST call attaches that header automatically.
5. `dispose()` discards the JWT from RAM. No persistence, refresh, or disk cache.

Diagram of the flow in [`doc/architecture.md`](../architecture.md) (API client section).

> **Important**: Umami v2 **does not expose static API keys**. The only way to authenticate the REST admin is username + password → JWT. If you rotate the password, all previously issued JWTs become invalid.

## What the SDK does NOT persist

To avoid surprises, here is what the SDK **does not** do:

- ❌ **Does not write** `apiUsername`/`apiPassword` to disk, SQLite, secure storage, or logs.
- ❌ **Does not persist** the JWT. Each app launch performs a fresh `login()`.
- ❌ **Does not log** the JWT or credentials (only failure warnings such as `"API login failed"`).
- ✅ **Does persist** (in `flutter_secure_storage`): the `deviceId` UUID v4 and the `first_launch` flag. Neither is secret.

## Best practices

### 1. Read credentials from the environment

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

Run with:

```bash
flutter run \
  --dart-define=UMAMI_API_USER=admin \
  --dart-define=UMAMI_API_PASS=secret
```

`--dart-define` values are compiled into the binary, but at least they separate code from values and enable multiple environments (dev/staging/prod).

### 2. Better: `flutter_secure_storage` at runtime

For client apps where you do not control the binary, load credentials from `flutter_secure_storage` populated through a secure channel (e.g. after your own backend login):

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

### 3. Do not commit credentials

- `.env`, `config.json`, `secrets.yaml` → in `.gitignore`.
- Use placeholder examples (`'admin'`, `'secret'`) in docs and tests, never real values.

### 4. Least privilege in Umami

Create an Umami user with **admin** or **user** role as needed. If you only read stats, do not use the owner account.

### 5. HTTPS always

`endpoint` must be `https://`. The JWT travels on every request and `login` sends the password in cleartext in the JSON body — only acceptable over TLS.

## Common confusions

### "Do I need an API token to track?"

**No.** Tracking is anonymous in Umami v2. You only need `websiteId` and `endpoint`. Credentials are exclusively for the REST admin client.

### "Is `userId` a credential?"

**No.** `userId` in `FlutterUmamiConfig` is a tracking identifier (sent as `id` in the payload). It correlates events from the same user across devices. It authenticates nothing.

### "What about `ipAddress`?"

Also not a credential. It's an override for the IP reported to the backend, useful for server-side tracking. Not auth.

### "The JWT expired, what do I do?"

The SDK does not handle expiry automatically. If REST calls start failing with 401, call `login()` again:

```dart
if (!api.isAuthenticated) {
  await api.login(username, password);
}
```

### "Can I inject my own pre-authenticated `UmamiApiPort`?"

Yes. Since v1.1.0 you can pass `apiClient:` to `createUmamiAnalytics()` with your own implementation. You then own the token lifecycle. See [9-api-client.md](9-api-client.md).

## Quick security checklist

Before shipping to production:

- [ ] `apiUsername`/`apiPassword` are not hardcoded in `lib/`.
- [ ] `.env` or config files holding secrets are in `.gitignore`.
- [ ] `endpoint` uses `https://`.
- [ ] `logger.minLevel` is not `verbose` in production (could leak payloads).
- [ ] If using identified tracking, `userId` does not contain sensitive personal data (in Umami the `userId` is visible in the admin panel).
- [ ] You rotated credentials if any were ever committed by mistake.

## See also

- [1-initialization.md](1-initialization.md) — full `createUmamiAnalytics()` parameters.
- [9-api-client.md](9-api-client.md) — REST client enabling and lifecycle.
- [`../architecture.md`](../architecture.md) — diagram of the `login → token` flow.
