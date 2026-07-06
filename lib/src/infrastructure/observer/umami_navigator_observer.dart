/// [NavigatorObserver] that auto-emits pageviews on push / replace / pop.
///
/// Attach it to [Navigator.observers] (or pass it through `MaterialApp` /
/// `CupertinoApp`) to track navigation without manual calls to
/// [UmamiCollector.trackPageView]. The observer never throws; tracking
/// failures are routed to [logger] when provided.
///
/// Layer: infrastructure (observer adapter).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';

/// [NavigatorObserver] that auto-emits pageviews on push / replace / pop.
///
/// Responsibilities:
/// - Listen to [NavigatorObserver.didPush] / [didReplace] / [didPop].
/// - Resolve a URL per route via [routeNameMapper] or `route.settings.name`.
/// - Delegate the actual pageview to the injected [UmamiCollector].
///
/// Layer: infrastructure.
class UmamiNavigatorObserver extends NavigatorObserver {
  final UmamiCollector _collector;

  /// When `false`, the observer still runs but no pageviews are emitted.
  ///
  /// Defaults to `true`.
  final bool autoTrack;

  /// Optional predicate that skips routes for which it returns `false`
  /// (e.g. ignore modal dialogs or splash routes).
  final bool Function(Route<dynamic> route)? routeFilter;

  /// Optional mapper that extracts the URL from a [Route].
  ///
  /// When `null`, falls back to `route.settings.name`. When the mapper
  /// returns `null`, the route is skipped.
  final String? Function(Route<dynamic> route)? routeNameMapper;

  /// Optional error sink for failed tracking calls.
  ///
  /// When `null`, tracking errors are silently dropped.
  final UmamiLogger? logger;

  /// Builds an observer wired to a [collector].
  ///
  /// Required: [collector] (the [UmamiCollector] that receives pageviews).
  /// Optional: [autoTrack] (defaults to `true`), [routeFilter],
  /// [routeNameMapper], and [logger].
  UmamiNavigatorObserver({
    required UmamiCollector collector,
    this.autoTrack = true,
    this.routeFilter,
    this.routeNameMapper,
    this.logger,
  }) : _collector = collector;

  /// Tracks a pageview for the just-pushed [route] (after filter / mapper).
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackIfNeeded(route);
  }

  /// Tracks a pageview for [newRoute] when present (after filter / mapper).
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute == null) return;
    _trackIfNeeded(newRoute);
  }

  /// Tracks a pageview for the now-visible [previousRoute] when present
  /// (after filter / mapper).
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null) return;
    _trackIfNeeded(previousRoute);
  }

  void _trackIfNeeded(Route<dynamic> route) {
    if (!autoTrack) return;
    final filter = routeFilter;
    if (filter != null && !filter(route)) return;

    final mapper = routeNameMapper;
    final url = mapper != null ? mapper(route) : route.settings.name;
    if (url == null) return;

    final title = mapper != null ? route.settings.name : null;

    unawaited(_runTrack(url: url, title: title));
  }

  Future<void> _runTrack({required String url, String? title}) async {
    try {
      await _collector.trackPageView(url: url, title: title);
    } catch (e, st) {
      logger?.error('UmamiNavigatorObserver track failed: $e\n$st');
    }
  }
}
