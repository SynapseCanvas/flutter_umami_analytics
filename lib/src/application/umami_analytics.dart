import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/api_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';

class FlutterUmamiAnalytics {
  final FlutterUmamiConfig config;
  final UmamiCollector _collector;
  final UmamiApiPort? apiClient;
  bool _disposed = false;

  FlutterUmamiAnalytics({
    required this.config,
    required UmamiCollector collector,
    this.apiClient,
  }) : _collector = collector;

  UmamiLogger get logger => config.logger;

  UmamiCollector get collector => _collector;

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

  Future<void> flush() => _collector.flush();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _collector.dispose();
    } finally {
      apiClient?.dispose();
    }
  }
}
