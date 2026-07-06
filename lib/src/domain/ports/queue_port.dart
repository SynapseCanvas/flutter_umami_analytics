/// Outbound port for offline event storage (domain layer, ports).
///
/// Abstracts the persistence layer used by the concrete tracking collector
/// when the network is unavailable. Implemented by the in-memory,
/// persisted (SQLite), and noop adapters in the `infrastructure` layer.
library;

import 'package:flutter_umami_analytics/src/domain/models/queued_event.dart';

export 'package:flutter_umami_analytics/src/domain/models/queued_event.dart';

/// Contract for an offline event store.
///
/// Holds serialized [QueuedEvent] payloads across app launches (depending
/// on the adapter) until the collector can flush them. Implementations
/// must be safe to call concurrently with `flush` / `dispose` on the
/// collector side.
abstract class UmamiQueue {
  /// Appends a serialized payload string to the queue.
  ///
  /// The [payload] is opaque to the queue — it is the JSON-encoded body
  /// produced by [UmamiPayload.toJson]. Returns when persistence (or
  /// memory allocation, depending on the adapter) completes. Async.
  Future<void> insert(String payload);

  /// Reads all currently queued events in insertion order.
  ///
  /// Used by the collector's `flush` to drain the queue on reconnect.
  /// Returns an empty list when the queue is empty. Async.
  Future<List<QueuedEvent>> getAll();

  /// Removes a single event by its underlying storage id.
  ///
  /// Called after a queued event is successfully sent to the upstream.
  /// No-op when [id] is unknown. Async.
  Future<void> delete(int id);

  /// Purges events older than [ttl].
  ///
  /// Called before the collector's `flush` when the configured queue
  /// declares an event-ttl policy. Async.
  Future<void> deleteExpired(Duration ttl);

  /// Current depth of the queue.
  ///
  /// Async; reads may race with concurrent [insert] / [delete] calls, the
  /// returned value is a best-effort snapshot.
  Future<int> get length;

  /// Releases any DB/IO resources held by the adapter.
  ///
  /// After this call the queue must not be used again. Called from
  /// the collector's `dispose`. Async.
  Future<void> close();
}
