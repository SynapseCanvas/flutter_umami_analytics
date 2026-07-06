/// Sealed variants configuring the offline event queue used by the
/// concrete tracking collector.
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

/// Default cap on the number of events retained by an active queue (in-memory
/// or persisted). Used when a variant does not specify otherwise.
const int kDefaultQueueMaxSize = 500;

/// Sealed base class for the offline queue strategy. Pick a variant via the
/// `disabled` / `inMemory` / `persisted` factories; the queue factory uses an
/// exhaustive `switch` over these variants. Layer: domain (pure Dart).
sealed class UmamiQueueConfig {
  /// Maximum number of events the queue may retain before dropping the oldest
  /// entry on enqueue. Implementations clamp to zero when disabled.
  int get maxSize;

  const UmamiQueueConfig();

  /// Zero-storage variant; send failures are dropped. Use for tests or when
  /// offline durability is explicitly unwanted.
  const factory UmamiQueueConfig.disabled() = DisabledUmamiQueueConfig;

  /// RAM-only queue. Events are lost on process death; use for short-lived
  /// sessions or when disk persistence is undesirable. [maxSize] bounds the
  /// FIFO buffer (defaults to [kDefaultQueueMaxSize]).
  const factory UmamiQueueConfig.inMemory({int maxSize}) =
      InMemoryUmamiQueueConfig;

  /// SQLite-backed queue that survives process death and app restarts.
  /// [maxSize] bounds the FIFO buffer, [databasePath] overrides the default
  /// file location, [eventTtl] evicts rows older than the given duration
  /// during flush (defaults to 48 hours).
  const factory UmamiQueueConfig.persisted({
    int maxSize,
    String? databasePath,
    Duration eventTtl,
  }) = PersistedUmamiQueueConfig;
}

/// Pick this variant to disable the offline queue entirely: send failures are
/// dropped silently. Suitable for tests, demos, or strict real-time-only
/// telemetry. Layer: domain.
class DisabledUmamiQueueConfig implements UmamiQueueConfig {
  @override
  final int maxSize = 0;

  const DisabledUmamiQueueConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DisabledUmamiQueueConfig;

  @override
  int get hashCode => 0;
}

/// Pick this variant for a RAM-only FIFO queue: zero disk I/O, but pending
/// events are lost when the process is killed. Layer: domain.
class InMemoryUmamiQueueConfig implements UmamiQueueConfig {
  /// Maximum FIFO length before the oldest entry is evicted on enqueue.
  @override
  final int maxSize;

  /// Builds an in-memory queue. [maxSize] defaults to [kDefaultQueueMaxSize].
  const InMemoryUmamiQueueConfig({this.maxSize = kDefaultQueueMaxSize});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InMemoryUmamiQueueConfig && maxSize == other.maxSize;

  @override
  int get hashCode => Object.hash(runtimeType, maxSize);
}

/// Pick this variant for a SQLite-backed FIFO queue that survives process
/// death and app restarts. Layer: domain.
class PersistedUmamiQueueConfig implements UmamiQueueConfig {
  /// Maximum number of rows retained before the oldest entry is evicted on
  /// enqueue.
  @override
  final int maxSize;

  /// Optional override for the SQLite file path; when null the adapter picks
  /// a default location namespaced by [FlutterUmamiConfig.instanceName].
  final String? databasePath;

  /// Maximum age retained during flush; rows older than this are evicted.
  /// Defaults to 48 hours.
  final Duration eventTtl;

  /// Builds a persisted queue. [maxSize] defaults to [kDefaultQueueMaxSize];
  /// [eventTtl] defaults to 48 hours; [databasePath] is optional.
  const PersistedUmamiQueueConfig({
    this.maxSize = kDefaultQueueMaxSize,
    this.databasePath,
    this.eventTtl = const Duration(hours: 48),
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistedUmamiQueueConfig &&
          maxSize == other.maxSize &&
          databasePath == other.databasePath &&
          eventTtl == other.eventTtl;

  @override
  int get hashCode => Object.hash(runtimeType, maxSize, databasePath, eventTtl);
}
