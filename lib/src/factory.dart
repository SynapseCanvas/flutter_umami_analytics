/// Adapter assembly for the [flutter_umami_analytics] SDK.
///
/// Provides [createUmamiAnalytics], the recommended entry point for consumers.
/// Builds every infrastructure adapter from a [FlutterUmamiConfig] and wires
/// them into a ready-to-use [FlutterUmamiAnalytics] facade.
///
/// Layer: factory.
library;

import 'package:http/http.dart' as http;

import 'package:flutter_umami_analytics/src/application/umami_analytics.dart';
import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/api/umami_api_client.dart';
import 'package:flutter_umami_analytics/src/infrastructure/collector/tracking_collector.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_id_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/device_info_service.dart';
import 'package:flutter_umami_analytics/src/infrastructure/http/default_http_client.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/queue_factory.dart';

const _kFirstOpenEvent = 'first_open';
const _kFirstOpenUrl = '/app/launch';

/// Assembles a fully wired [FlutterUmamiAnalytics] from a [FlutterUmamiConfig].
///
/// Call this during app bootstrap, before [runApp], so the queue is open and
/// (optionally) the API client is authenticated by the time the UI mounts.
/// Async: awaits queue opening and optional API login.
///
/// Params:
/// - [config] (required): drives every adapter and the facade.
/// - [httpClient] (optional): inject to reuse connections or in tests;
///   otherwise a new `http.Client()` is created internally and disposed by
///   the facade.
/// - [deviceId] (optional): inject for testing; otherwise a
///   [DefaultDeviceIdService] keyed by [FlutterUmamiConfig.instanceName].
/// - [deviceInfo] (optional): inject for testing; otherwise a
///   [DefaultDeviceInfoService].
/// - [recordFirstOpen] (default `false`): when `true`, emits a one-shot
///   `first_open` event on the first launch (per [FlutterUmamiConfig.instanceName]).
/// - [enableApi] (default `false`): when `true`, builds a [UmamiApiClient].
///   Set [apiUsername] / [apiPassword] to also authenticate it.
/// - [apiUsername] / [apiPassword]: required only when [enableApi] is `true`
///   and a pre-authenticated client is desired. Login failures degrade
///   gracefully: the [UmamiApiClient] is returned as `null` and a warning is
///   logged.
///
/// Returns the facade. The caller owns its lifecycle and must call
/// [FlutterUmamiAnalytics.dispose] when finished.
Future<FlutterUmamiAnalytics> createUmamiAnalytics(
  FlutterUmamiConfig config, {
  http.Client? httpClient,
  DeviceIdPort? deviceId,
  DeviceInfoPort? deviceInfo,
  bool recordFirstOpen = false,
  bool enableApi = false,
  String? apiUsername,
  String? apiPassword,
}) async {
  final logger = config.logger;

  final httpAdapter = DefaultHttpClient(
    client: httpClient,
    logger: logger,
    timeout: config.httpTimeout,
  );

  final queue =
      createQueue(config.queueConfig, instanceName: config.instanceName);
  final collector = TrackingCollector(
    config: config,
    httpClient: httpAdapter,
    queue: queue,
    deviceInfo: deviceInfo ?? DefaultDeviceInfoService(),
  );

  final apiClient = enableApi
      ? await _initApiClient(
          config.endpoint, logger, httpClient, apiUsername, apiPassword)
      : null;

  if (recordFirstOpen) {
    final deviceIdService =
        deviceId ?? DefaultDeviceIdService(instanceName: config.instanceName);
    await _sendFirstOpen(collector, deviceIdService);
  }

  logger.info(
    'Initialized (website=${config.websiteId}, endpoint=${config.endpoint})',
  );

  return FlutterUmamiAnalytics(
    config: config,
    collector: collector,
    apiClient: apiClient,
  );
}

Future<UmamiApiClient?> _initApiClient(
  String endpoint,
  UmamiLogger logger,
  http.Client? httpClient,
  String? apiUsername,
  String? apiPassword,
) async {
  final client =
      UmamiApiClient(baseUrl: endpoint, logger: logger, client: httpClient);
  if (apiUsername == null || apiPassword == null) {
    return client;
  }
  try {
    final ok = await client.login(apiUsername, apiPassword);
    if (!ok) {
      logger.warning('API login failed; client returned unauthenticated');
      return null;
    }
    return client;
  } catch (e, st) {
    logger.warning('API login threw: $e\n$st');
    return null;
  }
}

Future<void> _sendFirstOpen(
  TrackingCollector collector,
  DeviceIdPort deviceId,
) async {
  if (!await deviceId.isFirstLaunch()) return;
  await collector.trackEvent(name: _kFirstOpenEvent, url: _kFirstOpenUrl);
}
