import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';
import 'package:flutter_umami_analytics/src/domain/models/umami_queue_config.dart';
import 'package:flutter_umami_analytics/src/domain/ports/queue_port.dart';
import 'package:flutter_umami_analytics/src/domain/utils/instance_suffix.dart';

class PersistedQueue implements UmamiQueue {
  static const _table = 'queued_events';

  final int maxSize;
  final Duration eventTtl;
  final String? databasePath;
  final String _dbName;
  final UmamiLogger? _logger;

  Database? _db;
  Future<Database>? _openingFuture;
  bool _closed = false;

  PersistedQueue({
    this.maxSize = kDefaultQueueMaxSize,
    this.eventTtl = const Duration(hours: 48),
    this.databasePath,
    String? instanceName,
    UmamiLogger? logger,
  })  : _dbName = 'umami_queue${instanceSuffix(instanceName)}.db',
        _logger = logger;

  Future<Database> _ensureOpen() {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    final inflight = _openingFuture;
    if (inflight != null) return inflight;
    final completer = Completer<Database>();
    _openingFuture = completer.future;
    () async {
      try {
        final db = await _open();
        _db = db;
        completer.complete(db);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _openingFuture = null;
      }
    }();
    return completer.future;
  }

  Future<Database> _open() async {
    final basePath = databasePath ?? await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE $_table('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'payload TEXT NOT NULL, '
          'created_at INTEGER NOT NULL'
          ')',
        );
        await db.execute('CREATE INDEX idx_created_at ON $_table(created_at)');
      },
    );
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError(
        'PersistedQueue used before open; call _ensureOpen first',
      );
    }
    return db;
  }

  Future<int> _count(DatabaseExecutor db) async =>
      Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_table')) ??
      0;

  @override
  Future<void> insert(String payload) async {
    final db = await _ensureOpen();
    await db.transaction((txn) async {
      final count = await _count(txn);
      if (count >= maxSize) {
        await txn.rawQuery(
          'DELETE FROM $_table WHERE id IN (SELECT id FROM $_table ORDER BY id ASC LIMIT ?)',
          [count - maxSize + 1],
        );
      }
      await txn.insert(_table, {
        'payload': payload,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<List<QueuedEvent>> getAll() async {
    final db = await _ensureOpen();
    final rows = await db.query(_table, orderBy: 'id ASC');
    final logger = _logger;
    if (logger != null) {
      for (final row in rows) {
        if (row['created_at'] is! int) {
          logger.warning(
            'PersistedQueue: event id=${row['id']} has non-integer '
            'created_at (${row['created_at'].runtimeType}); falling back to now',
          );
        }
      }
    }
    return rows.map(QueuedEvent.fromMap).toList(growable: false);
  }

  @override
  Future<void> delete(int id) async {
    await _ensureOpen();
    await _requireDb().delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteExpired(Duration ttl) async {
    await _ensureOpen();
    final cutoff = DateTime.now().subtract(ttl).millisecondsSinceEpoch;
    await _requireDb().delete(
      _table,
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
  }

  @override
  Future<int> get length async {
    return _count(await _ensureOpen());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final db = _db;
    if (db == null) return;
    await db.close();
    _db = null;
  }
}
