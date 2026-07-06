# Registro

## `UmamiLogger`

Registrador con niveles y devolución de llamada opcional.

### Niveles

`verbose` < `debug` < `info` < `warning` (predeterminado) < `error` < `none`.

Los mensajes por debajo de `minLevel` se descartan.

### Configuración básica

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  logger: const UmamiLogger(minLevel: UmamiLogLevel.debug),
);

final analytics = await createUmamiAnalytics(config);
```

Ver [1-initialization.md](1-initialization.md) para el setup completo de `create()`.

### Devolución de llamada personalizada

Redirige los registros a tu sistema:

```dart
final logger = UmamiLogger(
  minLevel: UmamiLogLevel.info,
  customLogger: (level, message) {
    if (level == UmamiLogLevel.error) {
      myErrorReporting.capture(message);
    }
  },
);

final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  logger: logger,
);
```

Sin `customLogger`, los registros se imprimen por consola a través de `print()` con formato `[Umami] [LEVEL] message`.
