class DeviceInfoData {
  final String locale;
  final String screenResolution;
  final String platform;

  const DeviceInfoData({
    required this.locale,
    required this.screenResolution,
    required this.platform,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoData &&
          locale == other.locale &&
          screenResolution == other.screenResolution &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(locale, screenResolution, platform);
}
