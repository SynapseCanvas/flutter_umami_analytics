import 'package:flutter_umami_analytics/src/domain/utils/json_helpers.dart';

class QueuedEvent {
  final int? id;
  final String payload;
  final DateTime createdAt;
  late final Map<String, dynamic>? _decodedCache = decodeJsonObject(payload);

  QueuedEvent({this.id, required this.payload, required this.createdAt});

  Map<String, dynamic>? get decodedPayload => _decodedCache;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'payload': payload,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedEvent &&
          id == other.id &&
          payload == other.payload &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, payload, createdAt);
}
