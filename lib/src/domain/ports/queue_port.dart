import 'package:flutter_umami_analytics/src/domain/models/queued_event.dart';

export 'package:flutter_umami_analytics/src/domain/models/queued_event.dart';

abstract class UmamiQueue {
  Future<void> insert(String payload);
  Future<List<QueuedEvent>> getAll();
  Future<void> delete(int id);
  Future<void> deleteExpired(Duration ttl);
  Future<int> get length;
  Future<void> close();
}
