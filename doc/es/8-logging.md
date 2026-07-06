# Registro

## `UmamiLogger`

Registrador del SDK con niveles de severidad y devolución de llamada opcional. Pertenece a la capa `domain` (no acoplada a Flutter ni a `dart:developer`).

La instancia por defecto es `const UmamiLogger()`, con `minLevel: UmamiLogLevel.warning`. Se inyecta vía `FlutterUmamiConfig.logger` y también se expone como `analytics.logger` (alias de `config.logger`).

### Niveles

`enum UmamiLogLevel`, ordenado ascendentemente por `index`:

| Valor     | Uso                                                          |
| --------- | ------------------------------------------------------------ |
| `verbose` | Trazas más granulares: payloads y tiempos por llamada        |
| `debug`   | Diagnóstico durante desarrollo local                         |
| `info`    | Cambios de estado y ciclo de vida (flushes de cola, envíos)  |
| `warning` | Anomalías recuperables (reintentos, estado opcional ausente) |
| `error`   | Fallos que impidieron completar una operación                |
| `none`    | Centinela: silencia todo sin importar `minLevel`             |

Umbral por defecto: **`warning`**. Todo mensaje con `level.index < minLevel.index` se descarta antes de formatear.

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

Ver [1-initialization.md](1-initialization.md) para el setup completo de `createUmamiAnalytics()`.

### Devolución de callback personalizada

`customLogger` intercepta cada entrada que pasa el filtro de `minLevel`. Recibe `(UmamiLogLevel level, String message)`, donde `message` ya viene formateado como `[Umami] [LEVEL] message`.

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

Sin `customLogger`, los registros se imprimen por consola mediante `print()` con formato `[Umami] [LEVEL] message`.

### Helpers de nivel

`UmamiLogger` ofrece accesos directos además del método genérico `log(level, message)`:

- `verbose(String)` → `log(UmamiLogLevel.verbose, ...)`
- `debug(String)` → `log(UmamiLogLevel.debug, ...)`
- `info(String)` → `log(UmamiLogLevel.info, ...)`
- `warning(String)` → `log(UmamiLogLevel.warning, ...)`
- `error(String)` → `log(UmamiLogLevel.error, ...)`

### Casos de uso típicos

| Escenario                            | Configuración recomendada                            |
| ------------------------------------ | ---------------------------------------------------- |
| Producción sin ruido                 | `const UmamiLogger()` (`warning`)                    |
| Depuración en desarrollo             | `const UmamiLogger(minLevel: UmamiLogLevel.verbose)` |
| Integración con Sentry / Crashlytics | `customLogger` que filtre `error`                    |
| Silenciar todo (tests, benchmarks)   | `const UmamiLogger(minLevel: UmamiLogLevel.none)`    |

> Nota: `print()` sólo se invoca cuando **no** se proporciona `customLogger`. Si tu callback no imprime ni reenvía, la entrada se pierde silenciosamente.
