# Seguimiento

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

| Parámetro   | Tipo                    | Requerido | Descripción                                                                                          |
| ----------- | ----------------------- | --------- | ---------------------------------------------------------------------------------------------------- |
| `url`       | `String`                | sí        | URL/ruta de la página                                                                                |
| `title`     | `String?`               | no        | Título de la página                                                                                  |
| `referrer`  | `String?`               | no        | URL de referencia (prioridad sobre `firstReferrer`)                                                  |
| `hostname`  | `String?`               | no        | Anulación de hostname                                                                                |
| `language`  | `String?`               | no        | Anulación de idioma                                                                                  |
| `screen`    | `String?`               | no        | Anulación de resolución (predeterminada: resolución del dispositivo. Ver [7-device.md](7-device.md)) |
| `overrides` | `Map<String, dynamic>?` | no        | Anulaciones por llamada (ver [6-overrides.md](6-overrides.md))                                       |

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

## `enabled: false`

Con `enabled: false` en `FlutterUmamiConfig`, `trackPageView` y `trackEvent` retornan `false` inmediatamente sin enviar nada ni encolar.

## Carga útil automática

Ambos métodos incluyen en la carga útil:

- `screen` — resolución del dispositivo (rellenado automáticamente si no se pasa). Ver [7-device.md](7-device.md).
- `language` — configuración regional del dispositivo (rellenado automáticamente si no se pasa). Ver [7-device.md](7-device.md).
- `hostname` — configurado en `FlutterUmamiConfig`.
- `id` — `userId` si se configuró; si no, `sessionId` si se llamó a [`identify()`](5-identify.md).
- `ip_address` — si se configuró `ipAddress` en `FlutterUmamiConfig`.
