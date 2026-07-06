/// Outbound port for the persistent device identifier (domain layer, ports).
///
/// Abstracts the cross-launch device-id backing store. Implemented by
/// the default device-id service in the `infrastructure` layer
/// (secure-storage backed).
library;

/// Persistent, install-scoped device identifier contract.
///
/// Returns the same stable id across app launches; generates one on the
/// first call after install.
abstract class DeviceIdPort {
  /// Returns the stable device id, creating one on first call.
  ///
  /// Async because the backing store may perform I/O. The returned id is
  /// stable for the lifetime of the install unless [reset] is called.
  Future<String> getId();

  /// Returns `true` only on the very first launch for this install.
  ///
  /// Consumed by the concrete tracking collector to emit the synthetic
  /// first-install event and is then cleared by the adapter.
  Future<bool> isFirstLaunch();

  /// Clears the stored device id.
  ///
  /// Intended for test and admin flows; subsequent [getId] calls will
  /// generate a fresh id.
  Future<void> reset();
}
