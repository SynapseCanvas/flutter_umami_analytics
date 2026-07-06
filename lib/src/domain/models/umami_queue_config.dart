const int kDefaultQueueMaxSize = 500;

sealed class UmamiQueueConfig {
  int get maxSize;

  const UmamiQueueConfig();

  const factory UmamiQueueConfig.disabled() = DisabledUmamiQueueConfig;
  const factory UmamiQueueConfig.inMemory({int maxSize}) =
      InMemoryUmamiQueueConfig;
  const factory UmamiQueueConfig.persisted({
    int maxSize,
    String? databasePath,
    Duration eventTtl,
  }) = PersistedUmamiQueueConfig;
}

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

class InMemoryUmamiQueueConfig implements UmamiQueueConfig {
  @override
  final int maxSize;

  const InMemoryUmamiQueueConfig({this.maxSize = kDefaultQueueMaxSize});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InMemoryUmamiQueueConfig && maxSize == other.maxSize;

  @override
  int get hashCode => Object.hash(runtimeType, maxSize);
}

class PersistedUmamiQueueConfig implements UmamiQueueConfig {
  @override
  final int maxSize;
  final String? databasePath;
  final Duration eventTtl;

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
