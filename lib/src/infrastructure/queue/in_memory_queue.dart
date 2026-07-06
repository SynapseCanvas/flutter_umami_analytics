import 'dart:collection';

import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';

class InMemoryQueue implements UmamiQueue {
  final int maxSize;
  final LinkedHashMap<int, QueuedEvent> _events =
      LinkedHashMap<int, QueuedEvent>();
  int _nextId = 1;

  InMemoryQueue({this.maxSize = kDefaultQueueMaxSize});

  @override
  Future<void> insert(String payload) async {
    while (_events.length >= maxSize && _events.isNotEmpty) {
      _events.remove(_events.keys.first);
    }
    final id = _nextId++;
    _events[id] = QueuedEvent(
      id: id,
      payload: payload,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<QueuedEvent>> getAll() async =>
      UnmodifiableListView<QueuedEvent>(_events.values.toList(growable: false));

  @override
  Future<void> delete(int id) async {
    _events.remove(id);
  }

  @override
  Future<void> deleteExpired(Duration ttl) async {
    final cutoff = DateTime.now().subtract(ttl);
    _events.removeWhere((_, e) => e.createdAt.isBefore(cutoff));
  }

  @override
  Future<int> get length async => _events.length;

  @override
  Future<void> close() async {
    _events.clear();
  }
}
