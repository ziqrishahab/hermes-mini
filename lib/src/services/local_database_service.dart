import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';
import 'hermes_connection.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'hermes_offline_cache.db');

      return await openDatabase(
        path,
        version: 1,
        onOpen: (db) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_schedules (
              id TEXT PRIMARY KEY,
              name TEXT,
              schedule TEXT,
              prompt TEXT,
              enabled INTEGER DEFAULT 1,
              last_run TEXT,
              next_run TEXT,
              raw_json TEXT,
              updated_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_models (
              id TEXT PRIMARY KEY,
              name TEXT,
              provider TEXT,
              model TEXT,
              raw_json TEXT,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_sessions (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              started_at TEXT,
              source TEXT,
              message_count INTEGER DEFAULT 0,
              model TEXT,
              snippet TEXT,
              unread_count INTEGER DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cached_messages (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              tool_name TEXT,
              tool_status TEXT,
              tool_input TEXT,
              tool_output TEXT,
              is_streaming INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE INDEX idx_messages_session_time 
            ON cached_messages(session_id, timestamp ASC)
          ''');

          await db.execute('''
            CREATE INDEX idx_sessions_updated 
            ON cached_sessions(updated_at DESC)
          ''');
        },
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] DB initialization error: $e');
      rethrow;
    }
  }

  // --- SESSIONS ---

  Future<void> saveSessions(List<SessionSummary> sessions) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final s in sessions) {
        batch.insert(
          'cached_sessions',
          {
            'id': s.id,
            'title': s.title,
            'started_at': s.startedAt,
            'source': s.source,
            'message_count': s.messageCount,
            'model': s.model,
            'snippet': s.snippet,
            'unread_count': s.unreadCount,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving sessions: $e');
    }
  }

  Future<void> saveSession(SessionSummary s) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'cached_sessions',
        {
          'id': s.id,
          'title': s.title,
          'started_at': s.startedAt,
          'source': s.source,
          'message_count': s.messageCount,
          'model': s.model,
          'snippet': s.snippet,
          'unread_count': s.unreadCount,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving session: $e');
    }
  }

  Future<List<SessionSummary>> getSessions({String? query}) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> rows;

      if (query != null && query.trim().isNotEmpty) {
        final pattern = '%${query.trim()}%';
        rows = await db.query(
          'cached_sessions',
          where: 'title LIKE ? OR snippet LIKE ?',
          whereArgs: [pattern, pattern],
          orderBy: 'updated_at DESC',
        );
      } else {
        rows = await db.query(
          'cached_sessions',
          orderBy: 'updated_at DESC',
        );
      }

      return rows.map((row) {
        return SessionSummary(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? 'Untitled Session',
          startedAt: row['started_at'] as String? ?? '',
          source: row['source'] as String? ?? '',
          messageCount: (row['message_count'] as num?)?.toInt() ?? 0,
          model: row['model'] as String? ?? '',
          snippet: row['snippet'] as String? ?? '',
          unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error fetching cached sessions: $e');
      return [];
    }
  }

  Future<void> updateSessionSnippet(
    String sessionId,
    String snippet, {
    int? messageCount,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final updates = <String, dynamic>{
        'snippet': snippet,
        'updated_at': now,
      };
      if (messageCount != null) {
        updates['message_count'] = messageCount;
      }
      await db.update(
        'cached_sessions',
        updates,
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error updating session snippet: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final db = await database;
      await db.delete(
        'cached_messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await db.delete(
        'cached_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error deleting session: $e');
    }
  }

  // --- MESSAGES ---

  Future<void> saveMessages(String sessionId, List<ChatMessage> messages) async {
    if (sessionId.isEmpty) return;
    try {
      final db = await database;
      final batch = db.batch();

      // Clear existing to avoid duplicate drift when resyncing full list
      batch.delete(
        'cached_messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      for (final m in messages) {
        if (m.role == MessageRole.assistant &&
            m.content.trim().isEmpty &&
            m.toolName == null &&
            m.toolOutput == null) {
          continue;
        }
        batch.insert(
          'cached_messages',
          {
            'id': m.id,
            'session_id': sessionId,
            'role': m.role.name,
            'content': m.content,
            'timestamp': m.timestamp.millisecondsSinceEpoch,
            'tool_name': m.toolName,
            'tool_status': m.toolStatus,
            'tool_input': m.toolInput,
            'tool_output': m.toolOutput,
            'is_streaming': m.isStreaming ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving messages: $e');
    }
  }

  Future<void> saveMessage(String sessionId, ChatMessage m) async {
    if (m.role == MessageRole.assistant &&
        m.content.trim().isEmpty &&
        m.toolName == null &&
        m.toolOutput == null) {
      return;
    }
    if (sessionId.isEmpty) return;
    try {
      final db = await database;
      await db.insert(
        'cached_messages',
        {
          'id': m.id,
          'session_id': sessionId,
          'role': m.role.name,
          'content': m.content,
          'timestamp': m.timestamp.millisecondsSinceEpoch,
          'tool_name': m.toolName,
          'tool_status': m.toolStatus,
          'tool_input': m.toolInput,
          'tool_output': m.toolOutput,
          'is_streaming': m.isStreaming ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving single message: $e');
    }
  }

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    if (sessionId.isEmpty) return [];
    try {
      final db = await database;
      final rows = await db.query(
        'cached_messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC',
      );

      return rows.map((row) {
        final roleStr = row['role'] as String? ?? 'user';
        final role = MessageRole.values.firstWhere(
          (r) => r.name.toLowerCase() == roleStr.toLowerCase(),
          orElse: () => MessageRole.user,
        );

        final tsMs = (row['timestamp'] as num?)?.toInt() ?? 0;
        final ts = tsMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(tsMs)
            : DateTime.now();

        return ChatMessage(
          id: row['id'] as String? ?? '',
          role: role,
          content: row['content'] as String? ?? '',
          timestamp: ts,
          toolName: row['tool_name'] as String?,
          toolStatus: row['tool_status'] as String?,
          toolInput: row['tool_input'] as String?,
          toolOutput: row['tool_output'] as String?,
          isStreaming: false, // Messages restored from offline DB are never actively streaming
        );
      }).toList();
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error fetching cached messages: $e');
      return [];
    }
  }


  // --- SCHEDULES (CRON) ---

  Future<void> saveSchedules(List<Map<String, dynamic>> schedules) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final s in schedules) {
        final id = s['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        batch.insert(
          'cached_schedules',
          {
            'id': id,
            'name': s['name']?.toString() ?? '',
            'schedule': s['schedule']?.toString() ?? s['cron']?.toString() ?? '',
            'prompt': s['prompt']?.toString() ?? s['target']?.toString() ?? '',
            'enabled': s['enabled'] == false ? 0 : 1,
            'last_run': s['last_run']?.toString() ?? '',
            'next_run': s['next_run']?.toString() ?? '',
            'raw_json': jsonEncode(s),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving schedules: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final db = await database;
      final rows = await db.query('cached_schedules', orderBy: 'updated_at DESC');
      return rows.map((row) {
        final rawJson = row['raw_json'] as String?;
        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            return Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
          } catch (_) {}
        }
        return <String, dynamic>{
          'id': row['id'],
          'name': row['name'],
          'schedule': row['schedule'],
          'prompt': row['prompt'],
          'enabled': row['enabled'] == 1,
          'last_run': row['last_run'],
          'next_run': row['next_run'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error fetching cached schedules: $e');
      return [];
    }
  }

  // --- MODELS CATALOG ---

  Future<void> saveModels(List<Map<String, dynamic>> models) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final m in models) {
        final id = m['name']?.toString() ?? m['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        batch.insert(
          'cached_models',
          {
            'id': id,
            'name': m['name']?.toString() ?? id,
            'provider': m['provider']?.toString() ?? '',
            'model': m['model']?.toString() ?? id,
            'raw_json': jsonEncode(m),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error saving models: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      final db = await database;
      final rows = await db.query('cached_models', orderBy: 'updated_at DESC');
      return rows.map((row) {
        final rawJson = row['raw_json'] as String?;
        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            return Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
          } catch (_) {}
        }
        return <String, dynamic>{
          'name': row['name'],
          'provider': row['provider'],
          'model': row['model'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error fetching cached models: $e');
      return [];
    }
  }

  Future<void> clearAllCache() async {
    try {
      final db = await database;
      await db.delete('cached_messages');
      await db.delete('cached_sessions');
      await db.delete('cached_schedules');
      await db.delete('cached_models');
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error clearing cache: $e');
    }
  }
}
