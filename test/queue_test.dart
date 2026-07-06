import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_umami_analytics/flutter_umami_analytics.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/in_memory_queue.dart';
import 'package:flutter_umami_analytics/src/infrastructure/queue/noop_queue.dart';

DateTime _now() => DateTime.now();

DateTime _nowMs() =>
    DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch);

QueuedEvent _event(
        {int? id, String payload = '{"a":1}', DateTime? createdAt}) =>
    QueuedEvent(id: id, payload: payload, createdAt: createdAt ?? _now());

void main() {
  group('UmamiQueueConfig', () {
    test('InMemoryQueueConfig has correct maxSize', () {
      const config = UmamiQueueConfig.inMemory(maxSize: 10);
      expect(config.maxSize, 10);
    });

    test('InMemoryQueueConfig default maxSize is 500', () {
      const config = UmamiQueueConfig.inMemory();
      expect(config.maxSize, 500);
    });

    test('DisabledUmamiQueueConfig has maxSize 0', () {
      const config = UmamiQueueConfig.disabled();
      expect(config.maxSize, 0);
      expect(config, isA<DisabledUmamiQueueConfig>());
    });

    test('PersistedUmamiQueueConfig has configurable TTL', () {
      const config = PersistedUmamiQueueConfig(
        maxSize: 100,
        eventTtl: Duration(hours: 24),
      );
      expect(config.maxSize, 100);
      expect(config.eventTtl, const Duration(hours: 24));
      expect(config, isA<PersistedUmamiQueueConfig>());
    });
  });

  group('QueuedEvent', () {
    test('fromMap and toMap roundtrip', () {
      final original = _event(id: 1, payload: '{}', createdAt: _nowMs());
      final map = original.toMap();
      final restored = QueuedEvent.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.payload, original.payload);
      expect(restored.createdAt, original.createdAt);
    });

    test('fromMap with null id', () {
      final event = QueuedEvent.fromMap({
        'payload': '{}',
        'created_at': _now().toIso8601String(),
      });
      expect(event.id, isNull);
      expect(event.payload, '{}');
    });

    test('fromMap with null payload defaults to empty string', () {
      final event = QueuedEvent.fromMap({
        'created_at': _now().toIso8601String(),
      });
      expect(event.payload, '');
    });

    test('fromMap with invalid date falls back to now', () {
      final before = _now();
      final event = QueuedEvent.fromMap({
        'payload': '{}',
        'created_at': 'not-a-date',
      });
      final after = _now();
      expect(event.createdAt, isA<DateTime>());
      expect(
          event.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          true);
      expect(event.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          true);
    });

    test('toMap excludes null id', () {
      final event = _event();
      final map = event.toMap();
      expect(map.containsKey('id'), false);
      expect(map['payload'], '{"a":1}');
    });

    test('decodedPayload returns null for non-object JSON', () {
      final event = _event(id: 1, payload: 'not-json');
      expect(event.decodedPayload, isNull);
    });

    test('decodedPayload parses valid JSON map', () {
      final event = _event(id: 1, payload: '{"key":"val"}');
      expect(event.decodedPayload, isA<Map<String, dynamic>>());
      expect(event.decodedPayload!['key'], 'val');
    });

    test('decodedPayload returns null for list', () {
      final event = _event(id: 1, payload: '[1,2,3]');
      expect(event.decodedPayload, isNull);
    });

    test('decodedPayload returns null for primitive', () {
      final event = _event(id: 1, payload: '"hello"');
      expect(event.decodedPayload, isNull);
    });
  });

  group('InMemoryQueue', () {
    late InMemoryQueue queue;

    setUp(() {
      queue = InMemoryQueue(maxSize: 5);
    });

    tearDown(() async {
      await queue.close();
    });

    test('insert adds items', () async {
      await queue.insert('{"a":1}');
      await queue.insert('{"b":2}');
      expect(await queue.length, 2);
    });

    test('getAll returns items in order', () async {
      await queue.insert('{"a":1}');
      await queue.insert('{"b":2}');
      final all = await queue.getAll();
      expect(all.length, 2);
      expect(all[0].payload, '{"a":1}');
      expect(all[1].payload, '{"b":2}');
    });

    test('delete removes item by id', () async {
      await queue.insert('{"a":1}');
      final all = await queue.getAll();
      final id = all.first.id!;
      await queue.delete(id);
      expect(await queue.length, 0);
    });

    test('deleteExpired removes events older than ttl', () async {
      await queue.insert('{"old":true}');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await queue.deleteExpired(const Duration(milliseconds: 10));
      expect(await queue.length, 0);
    });

    test('deleteExpired keeps events newer than ttl', () async {
      await queue.insert('{"recent":true}');
      await queue.deleteExpired(const Duration(hours: 1));
      expect(await queue.length, 1);
    });

    test('overflows when maxSize is reached', () async {
      for (var i = 0; i < 7; i++) {
        await queue.insert('{"i":$i}');
      }
      expect(await queue.length, 5);
      final all = await queue.getAll();
      expect(all.first.payload, '{"i":2}');
      expect(all.last.payload, '{"i":6}');
    });

    test('close clears all events', () async {
      await queue.insert('{"a":1}');
      await queue.insert('{"b":2}');
      await queue.close();
      expect(await queue.length, 0);
    });
  });

  group('NoopQueue', () {
    late NoopQueue queue;

    setUp(() {
      queue = NoopQueue();
    });

    tearDown(() async {
      await queue.close();
    });

    test('insert does nothing', () async {
      await queue.insert('{}');
      expect(await queue.length, 0);
    });

    test('getAll returns empty', () async {
      final all = await queue.getAll();
      expect(all, isEmpty);
    });

    test('delete does not throw', () async {
      await expectLater(() => queue.delete(1), returnsNormally);
    });

    test('deleteExpired does not throw', () async {
      await expectLater(
        () => queue.deleteExpired(const Duration(hours: 1)),
        returnsNormally,
      );
    });

    test('length is zero', () async {
      expect(await queue.length, 0);
    });

    test('close does not throw', () async {
      await expectLater(() => queue.close(), returnsNormally);
    });
  });
}
