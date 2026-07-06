# Avanzado

Patrones de uso avanzado: evento `first_open`, sustitución de puertos, cliente HTTP personalizado, construcción manual del facade y referencias a temas especializados.

## Evento `first_open`

Si pasas `recordFirstOpen: true` a [createUmamiAnalytics()], se envía automáticamente un evento `first_open` (con `url: '/app/launch'`) la primera vez que el usuario abre la app.

```dart
final analytics = await createUmamiAnalytics(
  config,
  recordFirstOpen: true,
);
```

Persistencia y reenvío:

- El flag de "primera ejecución" se guarda en `flutter_secure_storage` bajo la clave `umami_first_launch{instanceName}` (vacío si `instanceName` es `null`).
- **iOS / macOS**: `flutter_secure_storage` respalda en Keychain, que **sobrevive a la desinstalación**. El evento se dispara una sola vez por dispositivo.
- **Android**: usa `EncryptedSharedPreferences`, que **se borra al desinstalar** o al limpiar los datos de la app. En esos casos `first_open` se reenvía.

El parámetro `recordFirstOpen` (por defecto `false`) activa la construcción del `DeviceIdPort`; si lo dejas en `false`, ninguna clave de "primera ejecución" se escribe ni lee. Cada `instanceName` mantiene su propio contador.

[createUmamiAnalytics()]: 1-initialization.md

## Collector personalizado

Implementa `UmamiCollector` para controlar el ciclo de envío (enrutamiento, agrupación, filtrado, etc.):

```dart
class CustomCollector implements UmamiCollector {
  @override
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
    return true;
  }

  @override
  Future<bool> trackEvent({
    required String name,
    String? url,
    String? title,
    String? referrer,
    Map<String, dynamic>? data,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
    return true;
  }

  @override
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  }) async {
    return true;
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {}
}
```

Inyéctalo construyendo el facade a mano (ver [Construcción manual del facade](#construcción-manual-del-facade)) o reemplazándolo en tus tests.

### Qué pierdes al reemplazar `TrackingCollector`

`TrackingCollector` (la implementación por defecto) orquesta varios mecanismos. Si la sustituyes por una implementación propia, dejas de tener:

- Comprobación de `FlutterUmamiConfig.enabled` (la hace el facade, no el collector).
- Cola offline (`UmamiQueue`) con reintentos.
- Consumo one-shot de `firstReferrer` en el primer `trackPageView`.
- Generación perezosa y reutilización de `sessionId` en `identify`.
- Captura automática de `hostname`, `language` y `screen` desde el dispositivo vía `DeviceInfoPort`.
- Posteo a `/api/send` con `safeAsync` (errores sólo se loguean, nunca se propagan).

### Alternativa: composición

Si sólo necesitas interceptar algunas llamadas, **envuelve** `TrackingCollector` en vez de reimplementar todo el port:

```dart
class FilteringCollector implements UmamiCollector {
  FilteringCollector(this._inner);
  final UmamiCollector _inner;

  @override
  Future<bool> trackEvent({
    required String name,
    String? url,
    Map<String, dynamic>? data,
    /* ... resto de parámetros ... */
    UmamiConfigOverrides? overrides,
  }) async {
    if (name == 'spam') return false; // filtrar
    return _inner.trackEvent(
      name: name,
      url: url,
      data: data,
      overrides: overrides,
    );
  }

  @override
  Future<bool> trackPageView({required String url, /* ... */}) =>
      _inner.trackPageView(url: url /* ... */);

  @override
  Future<bool> identify({required Map<String, dynamic> properties, /* ... */}) =>
      _inner.identify(properties: properties /* ... */);

  @override
  Future<void> flush() => _inner.flush();

  @override
  Future<void> dispose() => _inner.dispose();
}
```

Así conservas cola, referrer, sesión y captura de dispositivo sin reimplementarlos.

## Cliente HTTP personalizado

`createUmamiAnalytics()` acepta un `http.Client` para ajustar tiempos de espera, certificados, proxy, caché, etc. El mismo cliente lo comparten `DefaultHttpClient` (tracking) y `UmamiApiClient` (REST API) cuando lo pasas.

```dart
final analytics = await createUmamiAnalytics(
  config,
  httpClient: myCustomClient,
);
```

### Propiedad y ciclo de vida

| Origen del cliente        | `_ownsClient` | `dispose()` lo cierra |
| ------------------------- | ------------- | --------------------- |
| `httpClient: null` (def.) | `true`        | Sí                    |
| `httpClient: myClient`    | `false`       | **No**                |

Si inyectas tu propio `http.Client`, **tú eres responsable de cerrarlo**. La cascada `dispose()` del facade no lo hará. Útil para reutilizar conexiones entre servicios:

```dart
final sharedClient = http.Client();
try {
  final analytics = await createUmamiAnalytics(config, httpClient: sharedClient);
  // ...usar analytics...
  await analytics.dispose(); // NO cierra sharedClient
} finally {
  sharedClient.close(); // tú lo cierras
}
```

### Timeout

`httpTimeout` en `FlutterUmamiConfig` (por defecto `Duration(seconds: 5)`) **sólo** se aplica al `DefaultHttpClient` interno. Si inyectas tu propio cliente, configura el tiempo de espera en él.

## Construcción manual del facade

`createUmamiAnalytics()` es la vía recomendada. Si necesitas control total sobre cada adapter (tests, backends alternativos, lazy init), construye `FlutterUmamiAnalytics` directamente:

```dart
final analytics = FlutterUmamiAnalytics(
  config: config,
  collector: TrackingCollector(
    config: config,
    httpClient: httpAdapter,
    queue: queue,
    deviceInfo: deviceInfoService,
  ),
  apiClient: myApiPort, // UmamiApiPort? opcional
);
```

Consideraciones:

- `TrackingCollector` y `UmamiApiClient` son adapters internos (capa `infrastructure`), **no exportados** por el barrel `lib/flutter_umami_analytics.dart`. Para usarlos necesitas `import 'package:flutter_umami_analytics/src/...'` directo (rompe la encapsulación del barrel) o limitarte a implementar los ports (`UmamiCollector`, `UmamiApiPort`) tú mismo.
- El facade no llama a `flush()` automáticamente en `dispose()`. Llama a `flush()` antes si necesitas entregar la cola pendiente.
- Eres responsable de cablear `DeviceIdPort` / `DeviceInfoPort` si tus adapters los requieren.

Ver también [Sustitución del port] en [9-api-client.md] para el caso concreto del cliente REST.

[9-api-client.md]: 9-api-client.md
[Sustitución del port]: 9-api-client.md#sustitución-del-port

## Componentes expuestos

La instancia expone:

```dart
analytics.config      // FlutterUmamiConfig
analytics.collector   // UmamiCollector (port)
analytics.apiClient   // UmamiApiPort?
analytics.logger      // UmamiLogger (alias de config.logger)
```

Acceso directo al collector para tests o llamadas que bypassan el facade:

```dart
await analytics.collector.trackEvent(name: 'custom', data: {'k': 'v'});
```

> Recuerda: llamar al collector directamente **omite** la comprobación de `config.enabled` que hace el facade. Úsalo sólo si sabes que quieres emitir sin condicional.

Uso típico del cliente REST autenticado (cuando `enableApi: true`):

```dart
if (analytics.apiClient?.isAuthenticated ?? false) {
  final stats = await analytics.apiClient!.getWebsiteStats(
    config.websiteId,
    startAt: DateTime.now().subtract(const Duration(days: 7)),
    endAt: DateTime.now(),
  );
}
```

Más detalles en [9-api-client.md].

## Inyección en el árbol de widgets

Pasa la instancia por el árbol o inyéctala mediante un contenedor de DI (Provider, Riverpod, GetIt, etc.):

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({required this.analytics, super.key});
  final FlutterUmamiAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => analytics.trackEvent(name: 'button_click'),
      child: const Text('Click me'),
    );
  }
}
```

## Referencias a temas avanzados

| Tema                             | Documento                                                       |
| -------------------------------- | --------------------------------------------------------------- |
| Overrides por llamada            | [6-overrides.md](6-overrides.md)                                |
| `UmamiNavigatorObserver`         | [4-observer.md](4-observer.md)                                  |
| Cola offline y persistencia      | [2-queue.md](2-queue.md)                                        |
| IDs y info de dispositivo        | [7-device.md](7-device.md)                                      |
| Logging y niveles                | [8-logging.md](8-logging.md)                                    |
| Cliente REST (`UmamiApiPort`)    | [9-api-client.md](9-api-client.md)                              |
| Multi-instancia (`instanceName`) | [1-initialization.md](1-initialization.md#múltiples-instancias) |
