import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';

class UmamiNavigatorObserver extends NavigatorObserver {
  final UmamiCollector _collector;
  final bool autoTrack;
  final bool Function(Route<dynamic> route)? routeFilter;
  final String? Function(Route<dynamic> route)? routeNameMapper;
  final UmamiLogger? logger;

  UmamiNavigatorObserver({
    required UmamiCollector collector,
    this.autoTrack = true,
    this.routeFilter,
    this.routeNameMapper,
    this.logger,
  }) : _collector = collector;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackIfNeeded(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute == null) return;
    _trackIfNeeded(newRoute);
  }

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
