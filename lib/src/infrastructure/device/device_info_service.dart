import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/ports/device_info_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/device/platform_detector.dart';

class DefaultDeviceInfoService implements DeviceInfoPort {
  final UmamiLogger? logger;
  DeviceInfoData? _cached;
  PlatformDispatcher? _dispatcher;
  String? _platformLabel;

  DefaultDeviceInfoService({this.logger});

  @override
  DeviceInfoData gather() {
    final cached = _cached;
    if (cached != null) return cached;

    final dispatcher = _safeDispatcher();
    final info = DeviceInfoData(
      screenResolution: _resolveScreen(dispatcher),
      locale: _resolveLocale(dispatcher),
      platform: _platformLabel ??= PlatformDetector.detect().wire,
    );
    _cached = info;
    return info;
  }

  String _resolveScreen(PlatformDispatcher? dispatcher) {
    if (dispatcher == null) return 'unknown';
    final size = dispatcher.views.first.physicalSize;
    return '${size.width.toInt()}x${size.height.toInt()}';
  }

  String _resolveLocale(PlatformDispatcher? dispatcher) {
    if (dispatcher == null) return 'unknown';
    return dispatcher.locale.toString();
  }

  PlatformDispatcher? _safeDispatcher() {
    final cached = _dispatcher;
    if (cached != null) return cached;
    try {
      final d = WidgetsBinding.instance.platformDispatcher;
      _dispatcher = d;
      return d;
    } catch (e) {
      logger?.debug(
          'DefaultDeviceInfoService: platformDispatcher unavailable: $e');
      return null;
    }
  }
}
