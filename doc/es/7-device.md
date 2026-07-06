# Dispositivo

## ID de dispositivo persistente

Se genera un UUID v4 por instancia en la primera ejecución y se persiste con `flutter_secure_storage` (Keychain en iOS/macOS, EncryptedSharedPreferences en Android).

- iOS/macOS: sobrevive a la reinstalación (Keychain persiste).
- Android: se pierde al reinstalar o limpiar datos de la app.

Las claves de secure storage se prefijan con `instanceName`:

```text
umami_device_id_{instanceName}
umami_first_launch_{instanceName}
```

### `DeviceIdPort`

Interfaz pública para uso avanzado:

```dart
final deviceId = DefaultDeviceIdService(instanceName: 'default');
final id = await deviceId.getId();
final first = await deviceId.isFirstLaunch();
await deviceId.reset();
```

Inyecta una implementación personalizada pasando `deviceId` a [`create()`](1-initialization.md).

## Información del dispositivo

Recolectado automáticamente en cada evento:

| Campo              | Origen                                          | Ejemplo               |
| ------------------ | ----------------------------------------------- | --------------------- |
| `screenResolution` | `WidgetsBinding.platformDispatcher.views.first` | `1920x1080`           |
| `locale`           | `WidgetsBinding.platformDispatcher.locale`      | `en_US`               |
| `platform`         | `dart:io` Platform / `kIsWeb`                   | `ios`/`android`/`web` |

Inyecta una implementación personalizada pasando `deviceInfo` a `create()`:

```dart
class CustomDeviceInfo implements DeviceInfoPort {
  @override
  DeviceInfoData gather() => const DeviceInfoData(
    screenResolution: 'custom',
    locale: 'custom',
    platform: 'custom',
  );
}
```

## User-Agent

El cliente HTTP envía un User-Agent similar a navegador real, seleccionado por plataforma:

| Plataforma | User-Agent emulado |
| ---------- | ------------------ |
| Android    | Chrome 120 Mobile  |
| iOS        | Safari 17 Mobile   |
| macOS      | Safari 17 Desktop  |
| Windows    | Chrome 120 Desktop |
| Linux      | Chrome 120 Desktop |

Para usar un User-Agent distinto, inyecta tu propio `http.Client` vía el parámetro `httpClient` de [`create()`](1-initialization.md). Ver [10-advanced.md](10-advanced.md).
