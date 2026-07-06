/// Snapshot of device metadata attached to outbound Umami events.
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

/// Represents an immutable snapshot of the device metadata included with each
/// event (locale, screen size, platform). Produced by the device-info
/// service and consumed by the concrete tracking collector. Layer:
/// domain (pure Dart).
class DeviceInfoData {
  /// Locale string in BCP-47 form (e.g. `en-US`) sourced from the host app.
  final String locale;

  /// Screen resolution in `WxH` format (e.g. `1920x1080`).
  final String screenResolution;

  /// Platform name reported by the host runtime (e.g. `android`, `ios`,
  /// `macos`, `windows`, `linux`).
  final String platform;

  /// Builds a device-info snapshot. All three fields are required.
  const DeviceInfoData({
    required this.locale,
    required this.screenResolution,
    required this.platform,
  });

  /// Value equality over [locale], [screenResolution], and [platform].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoData &&
          locale == other.locale &&
          screenResolution == other.screenResolution &&
          platform == other.platform;

  /// Hash consistent with [operator==].
  @override
  int get hashCode => Object.hash(locale, screenResolution, platform);
}
