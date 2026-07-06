# Changelog

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
