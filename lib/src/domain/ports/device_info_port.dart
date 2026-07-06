/// Outbound port for device metadata (domain layer, ports).
///
/// Abstracts the platform-specific device information gathered by the
/// concrete tracking collector when building payloads. Implemented by
/// the default device-info service in the `infrastructure` layer.
library;

import 'package:flutter_umami_analytics/src/domain/models/device_info_data.dart';

export 'package:flutter_umami_analytics/src/domain/models/device_info_data.dart';

/// Read-only view of the host device's identifying metadata.
///
/// Implementations collect locale, screen resolution, platform, etc. once
/// per call; no caching is required at this layer.
abstract class DeviceInfoPort {
  /// Returns a [DeviceInfoData] snapshot describing the current device.
  ///
  /// Synchronous — implementations are expected to perform trivial
  /// platform queries without I/O on each call.
  DeviceInfoData gather();
}
