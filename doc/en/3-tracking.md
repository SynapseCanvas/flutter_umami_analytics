# Tracking

The `trackPageView` and `trackEvent` methods record page views and custom events, respectively. Both return `Future<bool>` and honor `FlutterUmamiConfig.enabled` (see [1-initialization.md](1-initialization.md)).

## `trackPageView()`

Records a page or screen view.

```dart
await analytics.trackPageView(
  url: '/home',
  title: 'Home Screen',
  referrer: 'https://google.com',
);
```

### Parameters

| Parameter   | Type                    | Required | Description                                                                                                                                                                            |
| ----------- | ----------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `url`       | `String`                | yes      | URL/path of the page                                                                                                                                                                   |
| `title`     | `String?`               | no       | Page title                                                                                                                                                                             |
| `referrer`  | `String?`               | no       | Referrer URL. Takes precedence over `firstReferrer`; if passed, `firstReferrer` is **not** consumed and remains pending for the next page view (see [6-overrides.md](6-overrides.md)). |
| `hostname`  | `String?`               | no       | Hostname override                                                                                                                                                                      |
| `language`  | `String?`               | no       | Language override                                                                                                                                                                      |
| `screen`    | `String?`               | no       | Resolution override (default: device resolution. See [7-device.md](7-device.md))                                                                                                       |
| `overrides` | `Map<String, dynamic>?` | no       | Per-call overrides (see [6-overrides.md](6-overrides.md))                                                                                                                              |

## `trackEvent()`

Records a custom event with optional data.

```dart
await analytics.trackEvent(
  name: 'purchase',
  url: '/checkout',
  data: {'product': 'premium', 'amount': 19.99},
);
```

### Parameters

| Parameter   | Type                    | Required | Description                                                                                |
| ----------- | ----------------------- | -------- | ------------------------------------------------------------------------------------------ |
| `name`      | `String`                | yes      | Event name                                                                                 |
| `url`       | `String?`               | no       | Associated URL (default: `FlutterUmamiConfig.defaultEventUrl`, which defaults to `/event`) |
| `title`     | `String?`               | no       | Page title                                                                                 |
| `referrer`  | `String?`               | no       | Referrer URL                                                                               |
| `data`      | `Map<String, dynamic>?` | no       | Additional event data                                                                      |
| `hostname`  | `String?`               | no       | Hostname override                                                                          |
| `language`  | `String?`               | no       | Language override                                                                          |
| `screen`    | `String?`               | no       | Resolution override                                                                        |
| `overrides` | `Map<String, dynamic>?` | no       | Per-call overrides                                                                         |

## Return value

Both methods return `Future<bool>`:

| Value   | Meaning                                                                                                                                  |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `true`  | The event was successfully sent to the `/api/send` endpoint. If the queue had pending events, `_autoFlush()` runs.                       |
| `false` | `FlutterUmamiConfig.enabled` is `false` **or** the send failed and the event was enqueued (or dropped if `queueConfig` is `disabled()`). |

## `enabled: false`

With `enabled: false` in `FlutterUmamiConfig`, the `FlutterUmamiAnalytics` facade returns `false` immediately without delegating to the collector, without sending anything, and without enqueueing. Useful for disabling tracking in debug without touching the call sites.

## Automatic payload

The collector builds a `UmamiPayload` with these fields filled in automatically when not passed explicitly:

- `website` — `FlutterUmamiConfig.websiteId`.
- `hostname` — `FlutterUmamiConfig.hostname`.
- `language` — `FlutterUmamiConfig.language` or, if `null`, the device locale. See [7-device.md](7-device.md).
- `screen` — device resolution. See [7-device.md](7-device.md).
- `ip_address` — only if `FlutterUmamiConfig.ipAddress` was set. See [6-overrides.md](6-overrides.md).
- `id` — `FlutterUmamiConfig.userId` if set; otherwise the `sessionId` lazily generated by [`identify()`](5-identify.md). If neither applies, it is omitted.
- `referrer` — see `firstReferrer` consumption below.

The `data` field of `trackEvent` is only serialized when it is non-`null` **and** non-empty (`data.isNotEmpty`).

### First-Referrer

`FlutterUmamiConfig.firstReferrer` is consumed exactly once: it is attached as `referrer` to the first `trackPageView` that does **not** receive an explicit `referrer`, and is then discarded. `trackEvent` does not consume it. See details in [6-overrides.md](6-overrides.md).

## Send behavior

1. The collector invokes `_send`, which performs the HTTP request to the `/api/send` endpoint (see [1-initialization.md](1-initialization.md) for `httpTimeout`).
2. If the request fails (no connection, timeout, HTTP error), the payload is serialized to JSON (`jsonEncode`) and inserted into the queue — unless `queueConfig` is `disabled()`, in which case it is dropped. See [2-queue.md](2-queue.md).
3. If the request succeeds, `_autoFlush()` runs to drain the pending queue. `flush()` and `_autoFlush()` share the `_flushing` flag (reentrant).

> Internal HTTP and queue failures are caught via `safeBool` / `safeAsync` and only logged: they never propagate to the caller (graceful degradation).
