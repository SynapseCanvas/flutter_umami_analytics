import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';

export 'package:flutter_umami_analytics/src/domain/models/umami_config.dart'
    show UmamiConfigOverrides;

abstract class UmamiCollector {
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  });

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

  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  });

  Future<void> flush();
  Future<void> dispose();
}
