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
import 'package:flutter_umami_analytics/src/domain/ports/api_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_id_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/domain/ports/http_client_port.dart';
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
/// Hexagonal injection — any port may be supplied by the caller. Injected ports
/// are NOT disposed by the facade (caller owns their lifecycle); the factory
/// only disposes ports it built internally.
///
/// Params:
/// - [config] (required): drives every adapter and the facade.
/// - [httpClientPort] (optional): inject a custom [HttpClientPort] for the
///   tracking collector (e.g. an adapter built on `dio`, `cronet_http`, etc.).
///   Takes precedence over [httpClient]; when set, [httpClient] is ignored for
///   tracking. Caller owns the lifecycle.
/// - [httpClient] (optional): inject a `package:http` [http.Client] to reuse
///   connections or in tests; otherwise a new `http.Client()` is created
///   internally and disposed by the facade. Shared between the tracking
///   collector (via [DefaultHttpClient]) and the REST API client
///   ([UmamiApiClient]) when both apply.
/// - [apiClient] (optional): inject a pre-built, optionally pre-authenticated
///   [UmamiApiPort] for the management REST endpoints. Takes precedence over
///   [enableApi]; when set, [enableApi], [apiUsername] and [apiPassword] are
///   ignored and no login is attempted. Caller owns the lifecycle.
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
  HttpClientPort? httpClientPort,
  http.Client? httpClient,
  UmamiApiPort? apiClient,
  DeviceIdPort? deviceId,
  DeviceInfoPort? deviceInfo,
  bool recordFirstOpen = false,
  bool enableApi = false,
  String? apiUsername,
  String? apiPassword,
}) async {
  final logger = config.logger;

  final HttpClientPort httpAdapter;
  final bool ownsHttpAdapter;
  if (httpClientPort != null) {
    httpAdapter = httpClientPort;
    ownsHttpAdapter = false;
  } else {
    httpAdapter = DefaultHttpClient(
      client: httpClient,
      logger: logger,
      timeout: config.httpTimeout,
    );
    ownsHttpAdapter = true;
  }

  final queue =
      createQueue(config.queueConfig, instanceName: config.instanceName);
  final collector = TrackingCollector(
    config: config,
    httpClient: httpAdapter,
    ownsHttpClient: ownsHttpAdapter,
    queue: queue,
    deviceInfo: deviceInfo ?? DefaultDeviceInfoService(),
  );

  final UmamiApiPort? resolvedApi;
  final bool ownsApiClient;
  if (apiClient != null) {
    resolvedApi = apiClient;
    ownsApiClient = false;
    logger.info('Using injected UmamiApiPort; skipping login');
  } else if (enableApi) {
    resolvedApi = await _initApiClient(
        config.endpoint, logger, httpClient, apiUsername, apiPassword);
    ownsApiClient = true;
  } else {
    resolvedApi = null;
    ownsApiClient = true;
  }

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
    apiClient: resolvedApi,
    ownsApiClient: ownsApiClient,
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
