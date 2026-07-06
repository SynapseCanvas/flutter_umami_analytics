# Seguimiento automático con NavigatorObserver

## `UmamiNavigatorObserver`

Observador de navegación que envía automáticamente `trackPageView` en cada cambio de ruta.

Pasa la instancia de analytics al widget que crea `MaterialApp`.

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

### Constructor

| Parámetro         | Tipo                                | Predeterminado | Descripción                                       |
| ----------------- | ----------------------------------- | -------------- | ------------------------------------------------- |
| `collector`       | `UmamiCollector`                    | requerido      | Instancia del collector                           |
| `autoTrack`       | `bool`                              | `true`         | Habilita/deshabilita el seguimiento automático    |
| `routeFilter`     | `bool Function(Route<dynamic>)?`    | `null`         | Filtro para excluir rutas del seguimiento         |
| `routeNameMapper` | `String? Function(Route<dynamic>)?` | `null`         | Mapea el nombre de ruta a URL personalizada       |
| `logger`          | `UmamiLogger?`                      | `null`         | Logger opcional para reportar errores de envío    |

### Eventos observados

- `didPush` — nueva ruta empujada a la pila.
- `didReplace` — ruta reemplazada.
- `didPop` — ruta removida. Registra la ruta anterior que queda visible. Esto puede duplicar el evento si la ruta ya se registró en su `didPush` original; usa `routeFilter` para evitarlo.

> El seguimiento se dispara y se olvida: los errores de red no se propagan al caller. Si pasas `logger`, los fallos se registrarán ahí; de lo contrario, implementa un `UmamiCollector` personalizado para capturarlos.

### Filtrado de rutas

Excluye rutas del seguimiento automático:

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeFilter: (route) => route.settings.name != '/login',
)
```

### Mapeo de nombres

Personaliza la URL enviada a Umami:

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  routeNameMapper: (route) {
    final name = route.settings.name;
    return name != null ? '/app$name' : null;
  },
)
```

Si `routeNameMapper` retorna `null`, la ruta no se registra.

### Deshabilitar

```dart
UmamiNavigatorObserver(
  collector: analytics.collector,
  autoTrack: false,
)
```

## Ver también

- Internamente llama a [`trackPageView`](3-tracking.md).
- Para manejo avanzado de errores implementa un collector personalizado: [10-advanced.md](10-advanced.md).
