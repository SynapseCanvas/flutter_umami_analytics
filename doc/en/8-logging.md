# Logging

## `UmamiLogger`

SDK logger with severity levels and an optional callback. Belongs to the `domain` layer (not coupled to Flutter or `dart:developer`).

The default instance is `const UmamiLogger()`, with `minLevel: UmamiLogLevel.warning`. It is injected via `FlutterUmamiConfig.logger` and also exposed as `analytics.logger` (alias of `config.logger`).

### Levels

`enum UmamiLogLevel`, ordered ascending by `index`:

| Value     | Usage                                                   |
| --------- | ------------------------------------------------------- |
| `verbose` | Most granular traces: payloads and per-call timings     |
| `debug`   | Diagnostics during local development                    |
| `info`    | State changes and lifecycle (queue flushes, sends)      |
| `warning` | Recoverable anomalies (retries, missing optional state) |
| `error`   | Failures that prevented an operation from completing    |
| `none`    | Sentinel: silences everything regardless of `minLevel`  |

Default threshold: **`warning`**. Any message with `level.index < minLevel.index` is discarded before formatting.

### Basic configuration

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  logger: const UmamiLogger(minLevel: UmamiLogLevel.debug),
);

final analytics = await createUmamiAnalytics(config);
```

See [1-initialization.md](1-initialization.md) for the full `createUmamiAnalytics()` setup.

### Custom callback

`customLogger` intercepts every entry that passes the `minLevel` filter. It receives `(UmamiLogLevel level, String message)`, where `message` is already formatted as `[Umami] [LEVEL] message`.

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

Without `customLogger`, logs are printed to the console via `print()` with the format `[Umami] [LEVEL] message`.

### Level helpers

`UmamiLogger` provides shortcuts in addition to the generic `log(level, message)` method:

- `verbose(String)` → `log(UmamiLogLevel.verbose, ...)`
- `debug(String)` → `log(UmamiLogLevel.debug, ...)`
- `info(String)` → `log(UmamiLogLevel.info, ...)`
- `warning(String)` → `log(UmamiLogLevel.warning, ...)`
- `error(String)` → `log(UmamiLogLevel.error, ...)`

### Typical use cases

| Scenario                               | Recommended configuration                            |
| -------------------------------------- | ---------------------------------------------------- |
| Production without noise               | `const UmamiLogger()` (`warning`)                    |
| Debugging in development               | `const UmamiLogger(minLevel: UmamiLogLevel.verbose)` |
| Sentry / Crashlytics integration       | `customLogger` filtering `error`                     |
| Silence everything (tests, benchmarks) | `const UmamiLogger(minLevel: UmamiLogLevel.none)`    |

> Note: `print()` is only invoked when `customLogger` is **not** provided. If your callback neither prints nor forwards, the entry is silently lost.
