import 'package:flutter_umami_analytics/src/domain/models/device_info_data.dart';

export 'package:flutter_umami_analytics/src/domain/models/device_info_data.dart';

abstract class DeviceInfoPort {
  DeviceInfoData gather();
}
