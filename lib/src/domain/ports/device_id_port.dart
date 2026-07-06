abstract class DeviceIdPort {
  Future<String> getId();
  Future<bool> isFirstLaunch();
  Future<void> reset();
}
