# Overrides, First-Referrer, and IP

Two mechanisms exist for modifying the `FlutterUmamiConfig` configuration (see [1-initialization.md](1-initialization.md)) on a per-call basis: **direct parameters** and the **`overrides` map**. Both apply to [`trackPageView`](3-tracking.md), [`trackEvent`](3-tracking.md), and [`identify`](5-identify.md), and never mutate the original `FlutterUmamiConfig`.

## Precedence

For fields that support both mechanisms (`hostname`, `language`), resolution follows this order in `TrackingCollector._buildPayload`:

```
direct parameter  >  overrides map  >  FlutterUmamiConfig  >  device value
```

1. If you pass `hostname:`/`language:` as a named parameter, that value wins.
2. Otherwise, the `overrides` map is applied (if it contains the key).
3. Otherwise, `FlutterUmamiConfig` is used.
4. If not set in the config, it falls back to the device value (locale, resolution).

## Direct parameters

`trackPageView` and `trackEvent` accept `hostname`, `language`, and `screen` as optional named parameters. They are the recommended way to override dimensions on a single call:

```dart
await analytics.trackPageView(
  url: '/checkout',
  hostname: 'checkout.example.com',
  language: 'es-MX',
  screen: '390x844',
);
```

`identify` does **not** accept direct parameters; only the `overrides` map.

## The `overrides` map

All three methods accept `overrides: Map<String, dynamic>?`. It is useful when you need to override `websiteId` or `userId` (which have no direct parameter), or when you build the map dynamically:

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

### Accepted keys

| Key         | Required type | Payload field | Applies to                                |
| ----------- | ------------- | ------------- | ----------------------------------------- |
| `websiteId` | `String`      | `website`     | `trackPageView`, `trackEvent`, `identify` |
| `hostname`  | `String`      | `hostname`    | `trackPageView`, `trackEvent`             |
| `language`  | `String`      | `language`    | `trackPageView`, `trackEvent`             |
| `userId`    | `String`      | `id`          | `trackPageView`, `trackEvent`             |

Type rules (implemented in `FlutterUmamiConfig.merge`):

- Values that are not `String` are **ignored** and the config value is kept.
- `language` and `userId` accept `null` in the config; `merge` only rewrites them if the key exists **and** the value is a `String`.
- Unlisted keys are silently ignored.

### Fields NOT overridable per call

These `FlutterUmamiConfig` fields **cannot** be overridden and are ignored if they appear in the map: `endpoint`, `enabled`, `queueConfig`, `ipAddress`, `instanceName`, `firstReferrer`, `httpTimeout`, `logger`. To change `ipAddress`, set it on `FlutterUmamiConfig.ipAddress` (see below).

## First-Referrer

`FlutterUmamiConfig.firstReferrer` is consumed once: it is included as `referrer` in the first `trackPageView` that does **not** receive an explicit `referrer`, and is then discarded (`TrackingCollector._consumeFirstReferrer`).

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  firstReferrer: 'https://twitter.com/share/abc123',
);

final analytics = await createUmamiAnalytics(config);
```

Notes:

- `trackEvent` does **not** consume `firstReferrer`.
- A `referrer` explicitly passed to `trackPageView` takes priority: in that case `firstReferrer` is **not** consumed and remains pending for the next page view without a `referrer`.
- `firstReferrer` is not a key in the `overrides` map; it is set only on `FlutterUmamiConfig`.

## IP address

For server-side tracking, set `ipAddress` on `FlutterUmamiConfig`:

```dart
final config = FlutterUmamiConfig(
  websiteId: '...',
  endpoint: '...',
  hostname: '...',
  ipAddress: '203.0.113.1',
);
```

It is included in the `ip_address` field of every event (`trackPageView`/`trackEvent`). `null` (the default) makes Umami infer it from the request. `identify` does not send `ip_address`. It is not overridable per call.
