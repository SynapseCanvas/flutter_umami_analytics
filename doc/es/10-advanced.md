# Avanzado

## Evento `first_open`

Si pasas `recordFirstOpen: true` a `createUmamiAnalytics()`, se envía automáticamente un evento `first_open` la primera vez que el usuario abre la app (estado persistido en `flutter_secure_storage`).

```dart
final analytics = await createUmamiAnalytics(
  config,
  recordFirstOpen: true,
);
```

El evento tiene `url: '/app/launch'`. No se vuelve a enviar aunque reinstales en iOS/macOS (Keychain persiste). En Android puede reenviarse si se limpian los datos de la app.

## Collector personalizado

Implementa `UmamiCollector` para controlar el ciclo de envío (enrutamiento, agrupación, filtrado):

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

## Cliente HTTP personalizado

`createUmamiAnalytics()` acepta un `http.Client` para ajustar tiempos de espera, certificados, proxy, caché, etc.

```dart
final analytics = await createUmamiAnalytics(
  config,
  httpClient: myCustomClient,
);
```

`httpTimeout` en `FlutterUmamiConfig` se aplica al `DefaultHttpClient` interno. Si pasas tu propio cliente, configura el tiempo de espera en él.

## Componentes expuestos

La instancia expone sus componentes:

```dart
final analytics = await createUmamiAnalytics(config);

// Tracking directo
await analytics.collector.trackEvent(name: 'custom', data: {'k': 'v'});

// Config actual
print(analytics.config.websiteId);

// API client (ver [9-api-client.md](9-api-client.md))
if (analytics.apiClient?.isAuthenticated ?? false) {
  final stats = await analytics.apiClient!.getWebsiteStats(
    'id',
    startAt: DateTime.now().subtract(const Duration(days: 7)),
    endAt: DateTime.now(),
  );
}
```

Más detalles del cliente REST en [9-api-client.md](9-api-client.md).

Pasa la instancia por el árbol de widgets o inyéctala a través de un contenedor de DI (Provider, Riverpod, GetIt, etc.):

```dart
class MyWidget extends StatelessWidget {
  final FlutterUmamiAnalytics analytics;
  const MyWidget({required this.analytics, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => analytics.trackEvent(name: 'button_click'),
      child: const Text('Click me'),
    );
  }
}
```
