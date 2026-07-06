import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';

class NoopQueue implements UmamiQueue {
  @override
  Future<void> insert(String payload) => Future<void>.value();

  @override
  Future<List<QueuedEvent>> getAll() =>
      Future<List<QueuedEvent>>.value(const <QueuedEvent>[]);

  @override
  Future<void> delete(int id) => Future<void>.value();

  @override
  Future<void> deleteExpired(Duration ttl) => Future<void>.value();

  @override
  Future<int> get length => Future<int>.value(0);

  @override
  Future<void> close() => Future<void>.value();
}
