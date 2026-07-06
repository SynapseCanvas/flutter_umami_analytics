import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/in_memory_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/persisted_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/noop_queue.dart';

UmamiQueue createQueue(UmamiQueueConfig config, {String? instanceName}) {
  return switch (config) {
    DisabledUmamiQueueConfig() => NoopQueue(),
    InMemoryUmamiQueueConfig(:final maxSize) => InMemoryQueue(maxSize: maxSize),
    PersistedUmamiQueueConfig(
      :final maxSize,
      :final eventTtl,
      :final databasePath
    ) =>
      PersistedQueue(
        maxSize: maxSize,
        eventTtl: eventTtl,
        databasePath: databasePath,
        instanceName: instanceName,
      ),
  };
}
