import 'dart:convert';

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_payload.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/collector_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/http_client_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/safe_async.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/endpoint_builder.dart';
import 'package:uuid/uuid.dart';

class TrackingCollector implements UmamiCollector {
  static const _uuid = Uuid();
  static const _kEventUrl = '/event';

  final FlutterUmamiConfig _config;
  final HttpClientPort _httpClient;
  final UmamiLogger _logger;
  final UmamiQueue _queue;
  final DeviceInfoPort _deviceInfo;

  String? _firstReferrer;
  String? _sessionId;
  bool _flushing = false;

  TrackingCollector({
    required FlutterUmamiConfig config,
    required HttpClientPort httpClient,
    required UmamiQueue queue,
    required DeviceInfoPort deviceInfo,
  })  : _config = config,
        _httpClient = httpClient,
        _logger = config.logger,
        _queue = queue,
        _deviceInfo = deviceInfo,
        _firstReferrer = config.firstReferrer;

  @override
  Future<bool> trackPageView({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    UmamiConfigOverrides? overrides,
  }) =>
      _track(
        logLabel: 'Track pageview',
        overrides: overrides,
        build: () => _buildPayload(
          url: url,
          title: title,
          referrer: referrer ?? _consumeFirstReferrer(),
          hostname: hostname,
          language: language,
          screen: screen,
        ),
      );

  @override
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
  }) =>
      _track(
        logLabel: 'Track event',
        overrides: overrides,
        build: () => _buildPayload(
          url: url ?? _kEventUrl,
          title: title,
          referrer: referrer,
          hostname: hostname,
          language: language,
          screen: screen,
          name: name,
          data: data,
        ),
      );

  Future<bool> _track({
    required String logLabel,
    required UmamiPayload Function() build,
    required UmamiConfigOverrides? overrides,
  }) async {
    if (!_config.enabled) return false;
    final payload = build();
    _logger.info('$logLabel: ${payload.url} title=${payload.title}');
    return _send(payload.toJson(), overrides);
  }

  @override
  Future<bool> identify({
    required Map<String, dynamic> properties,
    String? sessionId,
    UmamiConfigOverrides? overrides,
  }) async {
    if (!_config.enabled) return false;
    final resolved = _sessionId ?? sessionId ?? _newSessionId();
    _sessionId = resolved;
    return _sendIdentify(resolved, properties, overrides);
  }

  Future<bool> _sendIdentify(
    String resolvedSession,
    Map<String, dynamic> properties,
    UmamiConfigOverrides? overrides,
  ) {
    final payload = UmamiIdentifyPayload(
      website: _config.websiteId,
      sessionId: resolvedSession,
      data: properties,
    );
    _logger.info('Identify session: $resolvedSession data=$properties');
    return _send(payload.toJson(), overrides);
  }

  @override
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _doFlush();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _doFlush() async {
    if (_config.queueConfig case PersistedUmamiQueueConfig(:final eventTtl)) {
      await _queue.deleteExpired(eventTtl);
    }

    final events = await _queue.getAll();
    if (events.isEmpty) return;

    _logger.info('Flushing ${events.length} queued events');
    final endpoint = EndpointBuilder.sendEndpoint(_config.endpoint);

    final results = await Future.wait(
      events.map((event) => _flushOne(endpoint, event)),
    );
    final toDelete = <QueuedEvent>[];
    for (var i = 0; i < events.length; i++) {
      if (results[i]) toDelete.add(events[i]);
    }
    await Future.wait(
      toDelete.map(
        (event) => _deleteEvent(
            event, 'Skipping delete of flushed event with null id'),
      ),
    );
  }

  Future<bool> _flushOne(String endpoint, QueuedEvent event) async {
    final body = event.decodedPayload;
    if (body == null) {
      await _deleteEvent(
          event, 'Skipping queued event with undecodable payload');
      return false;
    }
    return safeBool(
      () => _httpClient.send(endpoint, body),
      onError: (e) => _logger.warning('Failed to flush event ${event.id}: $e'),
    );
  }

  Future<void> _deleteEvent(QueuedEvent event, String nullWarning) async {
    final id = event.id;
    if (id == null) {
      _logger.warning(nullWarning);
      return;
    }
    await _queue.delete(id);
  }

  @override
  Future<void> dispose() async {
    await safeAsync(
      () => flush(),
      onError: (e) => _logger.warning('Flush on dispose failed: $e'),
    );
    await _queue.close();
    _httpClient.dispose();
  }

  UmamiPayload _buildPayload({
    required String url,
    String? title,
    String? referrer,
    String? hostname,
    String? language,
    String? screen,
    String? name,
    Map<String, dynamic>? data,
  }) {
    final device = _deviceInfo.gather();
    return UmamiPayload(
      website: _config.websiteId,
      url: url,
      hostname: hostname ?? _config.hostname,
      language: language ?? _config.language ?? device.locale,
      referrer: referrer,
      screen: screen ?? device.screenResolution,
      title: title,
      name: name,
      data: data,
      id: _config.userId ?? _sessionId,
      ipAddress: _config.ipAddress,
    );
  }

  Future<bool> _send(
    Map<String, dynamic> body,
    UmamiConfigOverrides? overrides,
  ) async {
    final endpoint = EndpointBuilder.sendEndpoint(
      (overrides == null || overrides.isEmpty)
          ? _config.endpoint
          : _config.merge(overrides).endpoint,
    );
    final sent = await _httpClient.send(endpoint, body);
    if (!sent) {
      await _enqueue(body);
      return false;
    }
    await _autoFlush();
    return true;
  }

  Future<void> _enqueue(Map<String, dynamic> body) async {
    if (_config.queueConfig is DisabledUmamiQueueConfig) return;
    final ok = await safeBool(
      () => _queue.insert(jsonEncode(body)),
      onError: (e) => _logger.warning('Failed to enqueue event: $e'),
    );
    if (ok) _logger.info('Event queued');
  }

  Future<void> _autoFlush() async {
    if (_flushing) return;
    final length = await _queue.length;
    if (length == 0) return;
    _flushing = true;
    try {
      _logger.info('Auto-flushing $length pending events');
      await _doFlush();
    } finally {
      _flushing = false;
    }
  }

  String? _consumeFirstReferrer() {
    final ref = _firstReferrer;
    _firstReferrer = null;
    return ref;
  }

  String _newSessionId() => _uuid.v4();
}
