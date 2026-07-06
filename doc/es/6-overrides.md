# Overrides, First-Referrer e IP

Existen dos mecanismos para modificar la configuración de `FlutterUmamiConfig` (ver [1-initialization.md](1-initialization.md)) a nivel de llamada: **parámetros directos** y el **mapa `overrides`**. Ambos se aplican a [`trackPageView`](3-tracking.md), [`trackEvent`](3-tracking.md) e [`identify`](5-identify.md), y nunca mutan el `FlutterUmamiConfig` original.

## Precedencia

Para los campos que admiten ambos mecanismos (`hostname`, `language`), la resolución sigue este orden en `TrackingCollector._buildPayload`:

```
parámetro directo  >  overrides map  >  FlutterUmamiConfig  >  valor del dispositivo
```

1. Si pasas `hostname:`/`language:` como parámetro nombrado, ese valor gana.
2. Si no, se aplica el mapa `overrides` (si contiene la clave).
3. Si no, se usa `FlutterUmamiConfig`.
4. Si no está fijado en la config, se cae al dato del dispositivo (locale, resolución).

## Parámetros directos

`trackPageView` y `trackEvent` aceptan `hostname`, `language` y `screen` como parámetros nombrados opcionales. Son la forma recomendada para anular dimensiones en una sola llamada:

```dart
await analytics.trackPageView(
  url: '/checkout',
  hostname: 'checkout.example.com',
  language: 'es-MX',
  screen: '390x844',
);
```

`identify` **no** acepta parámetros directos; sólo el mapa `overrides`.

## Mapa `overrides`

Los tres métodos aceptan `overrides: Map<String, dynamic>?`. Es útil cuando necesitas anular `websiteId` o `userId` (que no tienen parámetro directo), o cuando construyes el mapa dinámicamente:

```dart
await analytics.trackPageView(
  url: '/checkout',
  overrides: {
    'hostname': 'checkout.example.com',
    'language': 'es-MX',
    'userId': 'temp-user-id',
    'websiteId': 'site-checkout',
  },
);
```

### Claves aceptadas

| Clave       | Tipo requerido | Campo del payload | Aplica a                                  |
| ----------- | -------------- | ----------------- | ----------------------------------------- |
| `websiteId` | `String`       | `website`         | `trackPageView`, `trackEvent`, `identify` |
| `hostname`  | `String`       | `hostname`        | `trackPageView`, `trackEvent`             |
| `language`  | `String`       | `language`        | `trackPageView`, `trackEvent`             |
| `userId`    | `String`       | `id`              | `trackPageView`, `trackEvent`             |

Reglas de tipo (implementadas en `FlutterUmamiConfig.merge`):

- Los valores que no son `String` se **ignoran** y se conserva el valor de la config.
- `language` y `userId` admiten `null` en la config; `merge` sólo los reescribe si la clave existe **y** el valor es `String`.
- Claves no listadas se ignoran silenciosamente.

### Campos NO anulables por llamada

Estos campos de `FlutterUmamiConfig` **no** se pueden overrides y se ignoran si aparecen en el mapa: `endpoint`, `enabled`, `queueConfig`, `ipAddress`, `instanceName`, `firstReferrer`, `httpTimeout`, `logger`. Para cambiar `ipAddress`, configúralo en `FlutterUmamiConfig.ipAddress` (ver abajo).

## First-Referrer

`FlutterUmamiConfig.firstReferrer` se consume una sola vez: se incluye como `referrer` en el primer `trackPageView` que **no** reciba un `referrer` explícito, y luego se descarta (`TrackingCollector._consumeFirstReferrer`).

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  firstReferrer: 'https://twitter.com/share/abc123',
);

final analytics = await createUmamiAnalytics(config);
```

Notas:

- `trackEvent` **no** consume `firstReferrer`.
- Un `referrer` pasado explícitamente a `trackPageView` tiene prioridad: en ese caso `firstReferrer` **no** se consume y queda pendiente para la siguiente página vista sin `referrer`.
- `firstReferrer` no es una clave del mapa `overrides`; se fija sólo en `FlutterUmamiConfig`.

## Dirección IP

Para seguimiento en el servidor, fija `ipAddress` en `FlutterUmamiConfig`:

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  ipAddress: '203.0.113.1',
);
```

Se incluye en el campo `ip_address` de cada evento (`trackPageView`/`trackEvent`). `null` (predeterminado) hace que Umami lo infiera de la petición. `identify` no envía `ip_address`. No es anulable por llamada.
