/// Public facade of the [flutter_umami_analytics] SDK.
///
/// Thin wrapper that enforces [FlutterUmamiConfig.enabled] and delegates every
/// call to the underlying [UmamiCollector]. Owns the lifecycle of the
/// collector and the optional [UmamiApiClient]; consumers only need to call
/// [dispose] when finished.
///
/// Layer: application.
library;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/api_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';

/// Consumer-facing entry point returned by [createUmamiAnalytics].
///
/// Responsibilities:
/// - Gate every tracking call on [FlutterUmamiConfig.enabled].
/// - Delegate to the injected [UmamiCollector].
/// - Manage lifecycle of the collector and the optional API client via
///   `dispose`.
///
/// Layer: application.
class FlutterUmamiAnalytics {
  /// Immutable runtime configuration consumed by every tracking call.
  final FlutterUmamiConfig config;
  final UmamiCollector _collector;
  final UmamiApiPort? apiClient;
  final bool _ownsApiClient;
  bool _disposed = false;

  /// Builds a facade wired to a [collector] and (optionally) an [apiClient].
  ///
  /// Required: [config] (drives every call) and [collector] (the underlying
  /// port). [apiClient] is only set when `enableApi: true` was passed to
  /// [createUmamiAnalytics]; otherwise it stays `null`.
  ///
  /// Set [ownsApiClient] to `false` when the caller injects a shared
  /// [UmamiApiPort] that must outlive this facade (e.g. an app-wide REST
  /// adapter). When `true` (default), the facade disposes the api client in
  /// [dispose].
  FlutterUmamiAnalytics({
    required this.config,
    required UmamiCollector collector,
    this.apiClient,
    bool ownsApiClient = true,
  })  : _collector = collector,
        _ownsApiClient = ownsApiClient;

  /// Convenience accessor for [FlutterUmamiConfig.logger].
  UmamiLogger get logger => config.logger;

  /// Exposes the underlying [UmamiCollector] port.
  ///
  /// Intended for advanced use cases such as test doubles or for callers that
  /// need access to collector-level operations not surfaced by the facade.
  UmamiCollector get collector => _collector;

  /// Records a pageview, gated on [config].
  ///
  /// Returns `false` when [FlutterUmamiConfig.enabled] is `false`; otherwise
  /// delegates to [UmamiCollector.trackPageView] and propagates its result.
  /// Async; resolves once the collector has enqueued or sent the payload.
  ///
  /// Params mirror [UmamiCollector.trackPageView]: [url] is the page path,
  /// [title] the page title, [referrer] the prior page (consumed only on the
  /// first pageview, then cleared by the collector), [hostname], [language]
  /// and [screen] are optional Umami dimensions, and [overrides] per-call
  /// config overrides.
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
    if (!config.enabled) return false;
    return _collector.trackPageView(
      url: url,
      title: title,
      referrer: referrer,
      hostname: hostname,
      language: language,
      screen: screen,
      overrides: overrides,
    );
  }

  /// Records a custom event, gated on [config].
  ///
  /// Returns `false` when [FlutterUmamiConfig.enabled] is `false`; otherwise
  /// delegates to [UmamiCollector.trackEvent] and propagates its result.
  /// Async; resolves once the collector has enqueued or sent the payload.
  ///
  /// [name] is required (the event identifier); [data] is the optional
  /// payload map. Other params mirror [UmamiCollector.trackEvent].
  Future<bool> trackEvent({
    required String name,
    String? url,
    String? title,
    String? referrer,
    Map<String, dynamic>? data,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) async {
    if (!config.enabled) return false;
    return _collector.trackEvent(
      name: name,
      url: url,
      title: title,
      referrer: referrer,
      data: data,
      hostname: hostname,
      language: language,
      screen: screen,
      overrides: overrides,
    );
  }

  /// Attaches user properties and (lazily) creates a session id, gated on
  /// [config].
  ///
  /// Returns `false` when [FlutterUmamiConfig.enabled] is `false`; otherwise
  /// delegates to [UmamiCollector.identify] and propagates its result.
  /// Async; resolves once the collector has enqueued or sent the payload.
  ///
  /// [properties] is required (the user attributes to attach). The session
  /// id is generated on the first call and reused for subsequent calls; pass
  /// [sessionId] to override it for this call only. [overrides] per-call
  /// config overrides.
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  }) async {
    if (!config.enabled) return false;
    return _collector.identify(
      properties: properties,
      sessionId: sessionId,
      overrides: overrides,
    );
  }

  /// Drains the offline queue and best-effort sends pending events.
  ///
  /// Delegates to [UmamiCollector.flush]. Call this before app suspend or
  /// before [dispose] when you want to maximise delivery. Async; resolves
  /// once the flush attempt completes (failures are logged, not thrown).
  Future<void> flush() => _collector.flush();

  /// Releases resources owned by the facade.
  ///
  /// Flushes are NOT automatic; call [flush] first if you need them. Then
  /// [dispose] closes the collector (which closes the queue and HTTP client
  /// when the collector owns it) and disposes the [apiClient] when the facade
  /// owns it. Idempotent: subsequent calls are no-ops.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _collector.dispose();
    } finally {
      if (_ownsApiClient) {
        apiClient?.dispose();
      }
    }
  }
}
