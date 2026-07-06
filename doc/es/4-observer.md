# Seguimiento automático con NavigatorObserver

## `UmamiNavigatorObserver`

[`NavigatorObserver`](https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html) que envía automáticamente un `trackPageView` en cada cambio de ruta relevante. Capa de infraestructura; delega el envío real al [`UmamiCollector`](2-configuracion.md) inyectado.

Pasa la instancia al widget que construye `MaterialApp` (o `CupertinoApp`):

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.analytics});

  final FlutterUmamiAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        UmamiNavigatorObserver(
          collector: analytics.collector,
        ),
      ],
      // ...
    );
  }
}
```

> Usa `analytics.collector` (getter público de la fachada) para no acoplarte a la implementación interna.

### Constructor

| Parámetro         | Tipo                                | Predeterminado | Descripción                                                                  |
| ----------------- | ----------------------------------- | -------------- | ---------------------------------------------------------------------------- |
| `collector`       | `UmamiCollector`                    | requerido      | Collector que recibe los pageviews.                                          |
| `autoTrack`       | `bool`                              | `true`         | Cuando `false`, el observer sigue registrado pero no emite eventos.          |
| `routeFilter`     | `bool Function(Route<dynamic>)?`    | `null`         | Predicado que excluye rutas (retorna `false` → se omite).                    |
| `routeNameMapper` | `String? Function(Route<dynamic>)?` | `null`         | Resuelve la URL enviada a Umami desde una `Route`. Si retorna `null`, omite. |
| `logger`          | `UmamiLogger?`                      | `null`         | Sink de errores de tracking. Si es `null`, los errores se descartan.         |

### Eventos observados

Cada hook aplica primero `autoTrack`, luego `routeFilter`, luego `routeNameMapper` (o fallback a `route.settings.name`). Solo se emite si sobrevive toda la cadena.

| Hook         | Ruta trackeada                                   | Notas                                                                                                                          |
| ------------ | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `didPush`    | `route` recién empujada                          | Siempre que pase el filtro / mapper.                                                                                           |
| `didReplace` | `newRoute` (ignora `oldRoute`)                   | Si `newRoute` es `null`, no hace nada.                                                                                         |
| `didPop`     | `previousRoute` (la que vuelve a quedar visible) | Si `previousRoute` es `null`, no hace nada. Puede duplicar el `didPush` original de esa ruta; usa `routeFilter` para evitarlo. |

### Resolución de URL y título

- Sin `routeNameMapper`: `url = route.settings.name`, `title = null`.
- Con `routeNameMapper`:
  - `url = routeNameMapper(route)`.
  - `title = route.settings.name` (el nombre original de la ruta), útil para conservar legibilidad en el dashboard de Umami aunque personalices la URL.
  - Si el mapper retorna `null`, la ruta **no se registra**.

### Fire-and-forget

El seguimiento se dispara y se olvida: los errores de red no se propagan al caller.

- Si pasas `logger`, los fallos (con stacktrace) se reportan ahí.
- Si `logger` es `null`, los errores se descartan silenciosamente.
- Para capturar métricas de fallos a nivel de negocio, implementa un `UmamiCollector` personalizado o envuelve el logger.

### Filtrado de rutas

Excluye rutas del seguimiento automático (útil para login, splash, diálogos modales):

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeFilter: (route) => route.settings.name != '/login',
)
```

### Mapeo de URLs

Personaliza la URL enviada a Umami (por ejemplo, prefijar rutas internas):

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeNameMapper: (route) {
    final name = route.settings.name;
    return name != null ? '/app$name' : null;
  },
)
```

Retornar `null` omite el tracking de esa ruta.

### Pausar el seguimiento (sin desregistrar)

`autoTrack: false` mantiene el observer en el `Navigator`, pero desactiva todas las emisiones. Útil para toggles reactivos sin reconstruir el árbol de widgets:

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  autoTrack: false,
)
```

## Ver también

- Internamente llama a [`trackPageView`](3-tracking.md).
- Para manejo avanzado de errores implementa un collector personalizado: [10-advanced.md](10-advanced.md).
