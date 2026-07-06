import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';

typedef UmamiConfigOverrides = Map<String, dynamic>;

class FlutterUmamiConfig {
  final String websiteId;
  final String endpoint;
  final String hostname;
  final String? language;
  final bool enabled;
  final String? userId;
  final String? ipAddress;
  final UmamiQueueConfig queueConfig;
  final UmamiLogger logger;
  final String? firstReferrer;
  final Duration httpTimeout;
  final String? instanceName;

  const FlutterUmamiConfig({
    required this.websiteId,
    required this.endpoint,
    required this.hostname,
    this.language,
    this.enabled = true,
    this.userId,
    this.ipAddress,
    this.queueConfig = const UmamiQueueConfig.inMemory(),
    this.logger = const UmamiLogger(),
    this.firstReferrer,
    this.httpTimeout = const Duration(seconds: 5),
    this.instanceName,
  });

  FlutterUmamiConfig copyWith({
    String? websiteId,
    String? endpoint,
    String? hostname,
    String? language,
    bool? enabled,
    String? userId,
    String? ipAddress,
    UmamiQueueConfig? queueConfig,
    UmamiLogger? logger,
    String? firstReferrer,
    Duration? httpTimeout,
    String? instanceName,
  }) {
    return FlutterUmamiConfig(
      websiteId: websiteId ?? this.websiteId,
      endpoint: endpoint ?? this.endpoint,
      hostname: hostname ?? this.hostname,
      language: language ?? this.language,
      enabled: enabled ?? this.enabled,
      userId: userId ?? this.userId,
      ipAddress: ipAddress ?? this.ipAddress,
      queueConfig: queueConfig ?? this.queueConfig,
      logger: logger ?? this.logger,
      firstReferrer: firstReferrer ?? this.firstReferrer,
      httpTimeout: httpTimeout ?? this.httpTimeout,
      instanceName: instanceName ?? this.instanceName,
    );
  }

  FlutterUmamiConfig merge([UmamiConfigOverrides? overrides]) {
    if (overrides == null || overrides.isEmpty) return this;
    return FlutterUmamiConfig(
      websiteId: _overrideString(overrides, 'websiteId', websiteId),
      endpoint: endpoint,
      hostname: _overrideString(overrides, 'hostname', hostname),
      language: _overrideNullableString(overrides, 'language', language),
      userId: _overrideNullableString(overrides, 'userId', userId),
      enabled: enabled,
      queueConfig: queueConfig,
      logger: logger,
      firstReferrer: firstReferrer,
      httpTimeout: httpTimeout,
      instanceName: instanceName,
      ipAddress: ipAddress,
    );
  }

  static String _overrideString(
    Map<String, dynamic> overrides,
    String key,
    String current,
  ) {
    final value = overrides[key];
    return value is String ? value : current;
  }

  static String? _overrideNullableString(
    Map<String, dynamic> overrides,
    String key,
    String? current,
  ) {
    if (!overrides.containsKey(key)) return current;
    final value = overrides[key];
    return value is String ? value : current;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlutterUmamiConfig &&
          websiteId == other.websiteId &&
          endpoint == other.endpoint &&
          hostname == other.hostname &&
          language == other.language &&
          enabled == other.enabled &&
          userId == other.userId &&
          ipAddress == other.ipAddress &&
          queueConfig == other.queueConfig &&
          logger == other.logger &&
          firstReferrer == other.firstReferrer &&
          httpTimeout == other.httpTimeout &&
          instanceName == other.instanceName;

  @override
  int get hashCode => Object.hash(
        websiteId,
        endpoint,
        hostname,
        language,
        enabled,
        userId,
        ipAddress,
        queueConfig,
        logger,
        firstReferrer,
        httpTimeout,
        instanceName,
      );
}
