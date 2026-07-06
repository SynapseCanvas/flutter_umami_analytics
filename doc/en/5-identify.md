# Session Identification

Associates arbitrary properties with the user session and lazily generates the `sessionId` that is then reused by `trackPageView`/`trackEvent`. Returns `Future<bool>` and honors `FlutterUmamiConfig.enabled` (see [1-initialization.md](1-initialization.md)).

## `identify()`

```dart
await analytics.identify(
  properties: {'tier': 'premium', 'plan': 'enterprise'},
  sessionId: 'custom-session-123',
);
```

### Parameters

| Parameter    | Type                    | Required | Description                                                               |
| ------------ | ----------------------- | -------- | ------------------------------------------------------------------------- |
| `properties` | `Map<String, dynamic>`  | yes      | Attributes to associate with the session. Serialized into `payload.data`. |
| `sessionId`  | `String?`               | no       | Custom session ID. Ignored if one already existed previously (see below). |
| `overrides`  | `Map<String, dynamic>?` | no       | Per-call configuration overrides (see [6-overrides.md](6-overrides.md))   |

### `sessionId` lifecycle

Resolution follows `_sessionId ?? sessionId ?? _newSessionId()` in `TrackingCollector.identify`:

1. If `_sessionId` is already set (by a previous call), the passed `sessionId` is **ignored** and the existing one is reused. The first value persists for the entire lifetime of the collector.
2. If `_sessionId` is `null` and `sessionId` is passed, that value is used and stored in `_sessionId`.
3. If `_sessionId` is `null` and no `sessionId` is passed, a new v4 UUID is generated via `uuid` (`_uuid.v4()`).

To start a distinct session, create a new instance with `createUmamiAnalytics()` (there is no API to reset the `sessionId` on the fly).

The `sessionId` (stored in `_sessionId`) is propagated as `id` in subsequent `UmamiPayload`s from `trackPageView`/`trackEvent`, with precedence: `FlutterUmamiConfig.userId ?? _sessionId`. If neither is set, the `id` field is omitted from the payload.

### Send and queue

The payload is sent along the same path as `trackPageView`/`trackEvent` (`_send` → endpoint `/api/send`). If the request fails and the queue is active, it is enqueued for retry; if `queueConfig` is `disabled()`, it is discarded. See [2-queue.md](2-queue.md) and [3-tracking.md](3-tracking.md#send-behavior).

### Example with login

```dart
Future<void> onUserLogin(User user) async {
  await analytics.identify(
    properties: {
      'userId': user.id,
      'email': user.email,
      'tier': user.subscriptionTier,
    },
  );
}
```

### Return value

Returns `Future<bool>`:

| Value   | Meaning                                                                                                                                                              |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `false` | `FlutterUmamiConfig.enabled` is `false` (the facade returns without delegating), **or** the send failed and the event was enqueued/discarded according to the queue. |
| `true`  | The identify was successfully sent to the `/api/send` endpoint.                                                                                                      |

### Generated payload

`UmamiIdentifyPayload.toJson()` wraps the body under `{type, payload}`. The `data` field is serialized **only** when `properties` is non-`null` **and** non-empty (`data.isNotEmpty`); otherwise it is omitted.

```json
{
  "type": "identify",
  "payload": {
    "website": "your-website-id",
    "sessionId": "4b6f1c3a-9d2e-4a8b-b7c5-1f3e9a0d2c4e",
    "data": {
      "userId": "usr_abc123",
      "email": "user@example.com",
      "tier": "premium"
    }
  }
}
```
