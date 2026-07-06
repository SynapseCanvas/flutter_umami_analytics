# Device

## Persistent device ID

`DefaultDeviceIdService` generates a UUID v4 per installation on the first call to `getId()` and persists it with `flutter_secure_storage` (Keychain on iOS/macOS, EncryptedSharedPreferences on Android).

- iOS/macOS: survives reinstalls (Keychain persists).
- Android: lost on reinstall or when app data is cleared.

> **Important:** the persistent ID **is not automatically attached to events**. It is used exclusively to detect the first launch and emit the synthetic `first_open` event when you pass `recordFirstOpen: true` to [`createUmamiAnalytics()`](1-initialization.md). To include a stable identifier on every event, set `userId` in `FlutterUmamiConfig` or call `identify()` (the spayload's `id` field is filled with `config.userId ?? sessionId`).

Secure storage keys are namespaced with `instanceName` via `instanceSuffix()`:

```text
# without instanceName
umami_device_id
umami_first_launch

# with instanceName = "foo"
umami_device_id_foo
umami_first_launch_foo
```

### `DeviceIdPort`

Domain contract for the persistent identifier. The factory builds `DefaultDeviceIdService` **only when `recordFirstOpen: true`**; otherwise the adapter is not instantiated and the `deviceId` parameter of [`createUmamiAnalytics()`](1-initialization.md) is ignored.

Custom implementation (the default adapter is not exported; inject your own `DeviceIdPort`):

```dart
class CustomDeviceId implements DeviceIdPort {
  @override
  Future<String> getId() async => 'my-stable-id';

  @override
  Future<bool> isFirstLaunch() async => false;

  @override
  Future<void> reset() async {/* ... */}
}
```

Inject it via `deviceId` in [`createUmamiAnalytics()`](1-initialization.md) **together with `recordFirstOpen: true`**; otherwise it has no effect.

## Device information

`DefaultDeviceInfoService.gather()` produces an immutable [`DeviceInfoData`] snapshot that `TrackingCollector` reads when building each payload:

| Field              | Source                                                                | Sent to Umami    | Example                   |
| ------------------ | --------------------------------------------------------------------- | ---------------- | ------------------------- |
| `screenResolution` | `WidgetsBinding.instance.platformDispatcher.views.first.physicalSize` | yes (`screen`)   | `1920x1080` (physical px) |
| `locale`           | `WidgetsBinding.instance.platformDispatcher.locale.toString()`        | yes (`language`) | `en_US`                   |
| `platform`         | `PlatformDetector.detect()` (`dart:io` Platform / `kIsWeb`)           | no               | `ios`/`android`/`web`     |

> `platform` is collected but **is not part of the payload**; `UserAgentService` uses it internally to choose the User-Agent.

The result is cached in memory after the first call; invoking `gather()` again does not query `WidgetsBinding` again. If `platformDispatcher` is not available (e.g. outside the Flutter zone), `screenResolution` and `locale` fall back to `"unknown"`.

Inject your own implementation by passing `deviceInfo` to [`createUmamiAnalytics()`](1-initialization.md):

```dart
class CustomDeviceInfo implements DeviceInfoPort {
  @override
  DeviceInfoData gather() => const DeviceInfoData(
    locale: 'es-ES',
    screenResolution: '1080x1920',
    platform: 'android',
  );
}
```

## User-Agent

`DefaultHttpClient` sets a realistic per-platform User-Agent via `UserAgentService.defaultUserAgent`:

| Platform      | Emulated User-Agent                                           |
| ------------- | ------------------------------------------------------------- |
| Android       | Chrome 120 Mobile (injects `Platform.operatingSystemVersion`) |
| iOS           | Safari 17 Mobile                                              |
| macOS         | Safari 17 Desktop                                             |
| Windows       | Chrome 120 Desktop                                            |
| Linux         | Chrome 120 Desktop                                            |
| Web / unknown | `Mozilla/5.0 (compatible; FlutterUmami/1.0)`                  |

The value is selected once (cached in `UserAgentService._cached`) and reused for the lifetime of the process.

To use a different User-Agent, inject your own `http.Client` via the `httpClient` parameter of [`createUmamiAnalytics()`](1-initialization.md) and set the `User-Agent` header on every `POST` request (the internal adapter always adds its own, so your client must override it). See [10-advanced.md](10-advanced.md).
