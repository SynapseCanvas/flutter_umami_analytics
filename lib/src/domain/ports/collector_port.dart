/// Outbound port for analytics tracking (domain layer, ports).
///
/// Defines the public-facing tracking contract used by
/// [FlutterUmamiAnalytics]. Implemented by the concrete tracking collector
/// in the `infrastructure` layer; consumers should depend on this interface
/// rather than the concrete implementation.
library;

import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';

export 'package:flutter_umami_analytics/src/domain/models/umami_config.dart'
    show UmamiConfigOverrides;

/// Public analytics surface.
///
/// All tracking flows through this interface: pageviews, custom events,
/// user identification, queue flushing, and resource disposal. Implementations
/// orchestrate the [UmamiQueue], [HttpClientPort], and [DeviceInfoPort].
abstract class UmamiCollector {
  /// Emits a pageview event.
  ///
  /// Parameters:
  /// - [url] (required): page path tracked by Umami.
  /// - [title]: optional human-readable page title.
  /// - [referrer]: previous page url; consumed only on the first pageview
  ///   after launch and then cleared.
  /// - [hostname]: overrides the device-derived hostname.
  /// - [language]: overrides the device-derived language tag.
  /// - [screen]: overrides the device-derived screen size.
  /// - [overrides]: per-call config overrides; see [UmamiConfigOverrides].
  ///
  /// Returns `true` when the event was accepted by the queue or sent
  /// successfully on the wire, `false` otherwise. Async.
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  });

  /// Emits a custom event.
  ///
  /// Parameters:
  /// - [name] (required): event identifier tracked by Umami.
  /// - [url]: optional page path; defaults to a synthetic `/event` url when
  ///   omitted.
  /// - [title]: optional human-readable context title.
  /// - [referrer]: previous page url; never consumed on event tracks.
  /// - [data]: optional custom payload map forwarded to Umami.
  /// - [hostname] / [language] / [screen]: override device defaults.
  /// - [overrides]: per-call config overrides; see [UmamiConfigOverrides].
  ///
  /// Returns `true` when accepted (sent or queued), `false` otherwise. Async.
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
  });

  /// Sets user/session identity for subsequent tracking calls.
  ///
  /// [properties] is a map of user traits forwarded to Umami. When
  /// [sessionId] is `null` the first call lazily generates a new session id
  /// which is then reused by all subsequent calls in this instance.
  /// [overrides] applies per-call config overrides; see
  /// [UmamiConfigOverrides].
  ///
  /// Returns `true` on accepted send/queue, `false` otherwise. Async.
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  });

  /// Drains the offline queue immediately, retrying all pending events.
  ///
  /// No-op when the queue is empty. Concurrent calls are coalesced by the
  /// implementation. Async.
  Future<void> flush();

  /// Releases the queue and HTTP transport held by the collector.
  ///
  /// Flushes any pending events first, then closes the queue and disposes
  /// the HTTP client via [HttpClientPort.dispose]. Expected to be
  /// idempotent. Async.
  Future<void> dispose();
}
