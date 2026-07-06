# Changelog

## 1.0.1

- Fix: per-call `UmamiConfigOverrides` (`websiteId`, `hostname`, `language`, `userId`) now applied to the outgoing payload in `trackPageView`, `trackEvent`, and `identify`. Previously the merged config was computed but the payload was still built from the base config, so overrides had no effect on those fields.
- Docs: added dartdoc (`///`) to all public API symbols across `domain`, `application`, `infrastructure`, and `factory.dart`.
- Docs: added English documentation set under `doc/en/` (initialization, queue, tracking, observer, identify, overrides, device, logging, API client, advanced) and refreshed Spanish docs under `doc/es/`.

## 1.0.0

- Initial release.
- Pageview and event tracking with automatic device info (locale, screen, User-Agent per platform).
- Offline queue strategies: `disabled`, `inMemory`, `persisted` (SQLite with TTL, auto-flush).
- Persistent device ID via `flutter_secure_storage`, namespaced per instance.
- `UmamiNavigatorObserver` for auto-tracking route pushes, replaces, and pops (`routeFilter` and `routeNameMapper` hooks).
- Multi-instance support with isolated SQLite queue and secure storage keys per `instanceName`.
- Optional REST API client (`enableApi`): login, websites, stats, pageviews, metrics, active visitors, events, sessions, teams, users.
- Per-call config overrides (`websiteId`, `hostname`, `language`, `userId`).
- One-time `firstReferrer` consumed by the first `trackPageView`.
- Lazy `sessionId` generated on first `identify()`.
- Configurable `UmamiLogger` (six levels, custom sink callback).
- Hexagonal architecture: pure-Dart `domain` with swappable `port` adapters.
