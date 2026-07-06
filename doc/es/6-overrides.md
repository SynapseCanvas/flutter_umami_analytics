# Overrides, First-Referrer e IP

Modifican el comportamiento configurado en `FlutterUmamiConfig` (ver [1-initialization.md](1-initialization.md)). Se aplican a [`trackPageView`](3-tracking.md), [`trackEvent`](3-tracking.md) e [`identify`](5-identify.md).

## Overrides por llamada

`trackPageView`, `trackEvent` e `identify` aceptan un parámetro `overrides` que modifica la configuración sólo para esa llamada.

```dart
await analytics.trackPageView(
  url: '/checkout',
  overrides: {
    'hostname': 'checkout.example.com',
    'language': 'es-MX',
    'userId': 'temp-user-id',
  },
);
```

### Claves aceptadas

| Clave       | Tipo     | Descripción                                  |
| ----------- | -------- | -------------------------------------------- |
| `websiteId` | `String` | ID del sitio web para esta llamada           |
| `hostname`  | `String` | Hostname enviado en la carga útil            |
| `language`  | `String` | Idioma del cliente para esta llamada         |
| `userId`    | `String` | Identificador de usuario para esta llamada   |

Valores que no son `String` se ignoran silenciosamente. Otras claves de `FlutterUmamiConfig` (`endpoint`, `enabled`, `queueConfig`, `ipAddress`, `instanceName`, `firstReferrer`, `httpTimeout`, `logger`) no admiten anulación por llamada. Para anular la IP, configúrala en `FlutterUmamiConfig.ipAddress` (ver abajo).

## First-Referrer

`firstReferrer` se consume una sola vez: se incluye como `referrer` en el primer `trackPageView` que no reciba un `referrer` explícito, y luego se descarta.

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  firstReferrer: 'https://twitter.com/share/abc123',
);

final analytics = await createUmamiAnalytics(config);
```

`trackEvent` no consume `firstReferrer`. Un `referrer` pasado a `trackPageView` tiene prioridad sobre `firstReferrer`.

## Anulación de dirección IP

Para seguimiento en el servidor:

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  ipAddress: '203.0.113.1',
);
```

Se incluye en el campo `ip_address` de la carga útil de cada evento.
