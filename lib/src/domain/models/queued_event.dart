/// Queue-row model persisted by [PersistedQueue] / read by [InMemoryQueue].
///
/// Part of the domain layer (pure Dart, no Flutter, no http, no sqflite).
library;

import 'package:flutter_umami_analytics/src/domain/utils/json_helpers.dart';

/// Represents a single event stored in the offline queue before being sent to
/// Umami. Carries the serialized JSON [payload], the row [id] (assigned by
/// SQLite for the persisted queue, null in-memory), and the [createdAt]
/// timestamp used for FIFO ordering and TTL eviction. Layer: domain.
class QueuedEvent {
  /// SQLite auto-increment row id; null for in-memory entries or before
  /// insertion.
  final int? id;

  /// Serialized JSON envelope (the output of [UmamiPayload.toJson]) ready to
  /// be POSTed to `/api/send`.
  final String payload;

  /// Wall-clock instant when the event was enqueued.
  final DateTime createdAt;
  late final Map<String, dynamic>? _decodedCache = decodeJsonObject(payload);

  /// Builds a queue entry. [payload] and [createdAt] are required; [id] is
  /// assigned by the persisted queue adapter on insert.
  QueuedEvent({this.id, required this.payload, required this.createdAt});

  /// Lazily decoded view of [payload]; null when the payload is not a JSON
  /// object. Computed once and cached on first access.
  Map<String, dynamic>? get decodedPayload => _decodedCache;

  /// Serializes to the SQLite row shape `{id?, payload, created_at}` where
  /// `created_at` is milliseconds since epoch.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'payload': payload,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  /// Defensive factory: tolerates missing or wrong-type columns by falling
  /// back to safe defaults (empty payload, current time, null id).
  factory QueuedEvent.fromMap(Map<String, Object?> map) {
    final rawMs = map['created_at'];
    final ms = rawMs is int
        ? rawMs
        : int.tryParse('$rawMs') ?? DateTime.now().millisecondsSinceEpoch;
    final rawId = map['id'];
    final rawPayload = map['payload'];
    return QueuedEvent(
      id: rawId is int ? rawId : null,
      payload: rawPayload is String ? rawPayload : '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Value equality over [id], [payload], and [createdAt].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedEvent &&
          id == other.id &&
          payload == other.payload &&
          createdAt == other.createdAt;

  /// Hash consistent with [operator==] over [id], [payload], [createdAt].
  @override
  int get hashCode => Object.hash(id, payload, createdAt);
}
