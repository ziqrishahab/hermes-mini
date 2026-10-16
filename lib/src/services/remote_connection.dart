import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:dio/dio.dart";
import "../models/connection_config.dart";
import "hermes_connection.dart";
class RemoteConnection extends HermesConnection {
  final ConnectionConfig config;
  late final Dio _dio;
  String? _activeSessionId;
  @override
  String? get activeSessionId => _activeSessionId;
  @override
  set activeSessionId(String? id) => _activeSessionId = id;

  String? _cookieHeader;
  String? _accessToken;
  bool _authenticated = false;
  final Map<String, WebSocket> _activeChatSockets = {};

  late final String _baseUrl;
  late final String _wsBaseUrl;

  RemoteConnection(this.config) {
    var rawUrl = (config.apiUrl ?? "").trim().replaceAll(RegExp(r"/$"), "");
    if (!rawUrl.startsWith("http://") && !rawUrl.startsWith("https://")) {
      rawUrl = "http://$rawUrl";
    }
    _baseUrl = rawUrl;

    final uri = Uri.parse(_baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 9119);
    _wsBaseUrl = '$wsScheme://${uri.host}:$port/api/ws';

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        if (config.apiKey?.isNotEmpty ?? false)
          "Authorization": "Bearer ${config.apiKey}",
        "Accept": "application/json, text/event-stream, */*",
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException err, ErrorInterceptorHandler handler) async {
        if (err.response?.statusCode == 401 || err.response?.statusCode == 302) {
          final ok = await authenticate();
          if (ok) {
            try {
              final opts = err.requestOptions;
              opts.headers['Cookie'] = _cookieHeader;
              if (_accessToken != null) {
                opts.headers['Authorization'] = 'Bearer $_accessToken';
              }
              final cloneReq = await _dio.fetch(opts);
              return handler.resolve(cloneReq);
            } catch (e) {
              return handler.next(err);
            }
          }
        }
        return handler.next(err);
      },
    ));
  }

  Future<bool> authenticate() async {
    final credential = config.apiKey?.trim() ?? '';
    if (credential.isEmpty) return false;

    try {
      final res = await _dio.post(
        "/auth/password-login",
        data: {
          "provider": "basic",
          "username": "admin",
          "password": credential,
        },
        options: Options(validateStatus: (s) => true),
      );
      if (res.statusCode == 200) {
        final setCookies = res.headers['set-cookie'] ?? [];
        if (setCookies.isNotEmpty) {
          final cookiePairs = setCookies.map((sc) => sc.split(';').first.trim()).toList();
          _cookieHeader = cookiePairs.join('; ');
          _dio.options.headers['Cookie'] = _cookieHeader;
        }
        for (final sc in setCookies) {
          if (sc.startsWith('hermes_session_at=')) {
            final rawVal = sc.split(';').first.substring('hermes_session_at='.length);
            _accessToken = rawVal.replaceAll('"', '').trim();
            _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
          }
        }
        _authenticated = true;
        return true;
      }
    } catch (_) {}

    if (credential.isNotEmpty) {
      try {
        _dio.options.headers['Authorization'] = 'Bearer $credential';
        final check = await _dio.get("/api/auth/me", options: Options(validateStatus: (s) => true));
        if (check.statusCode == 200) {
          _accessToken = credential;
          _authenticated = true;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> testConnection() async {
    await authenticate();

    try {
      final res = await _dio.get("/api/auth/me");
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      final res = await _dio.get("/api/models");
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      final res = await _dio.get("/api/status");
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      final res = await _dio.get("/api/health");
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      final res = await _dio.get("/health");
      return res.statusCode == 200;
    } catch (_) {}

    return _authenticated;
  }
  @override
  Future<String> health() async {
    final res = await _dio.get("/health");
    return res.data.toString();
  }

  @override
  Future<String> getSkillContent(String skillName) async {
    try {
      final res = await _dio.get("/api/skills/content", queryParameters: {"name": skillName});
      if (res.data is Map<String, dynamic> && res.data['content'] != null) {
        return res.data['content'].toString();
      }
      final str = res.data.toString();
      if (!str.contains('<!doctype html>')) return str;
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/skills/$skillName/content");
      final str = res.data.toString();
      if (!str.contains('<!doctype html>')) return str;
    } catch (_) {}

    return '';
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    try {
      final res = await _dio.get("/api/sessions/$sessionId/messages");
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      if (raw is Map) {
        final list = (raw['messages'] as List<dynamic>?) ?? [];
        return list.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      } else if (raw is List) {
        return raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/sessions/$sessionId/messages");
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      if (raw is List) {
        return raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<Map<String, bool>> getPlatformEnabled() async {
    try {
      final platforms = await getMessagingPlatforms();
      if (platforms.isNotEmpty) {
        return {
          for (final p in platforms)
            if (p['id'] != null) p['id'].toString(): p['enabled'] == true,
        };
      }
    } catch (_) {}
    try {
      final res = await _dio.get("/v1/platforms");
      final map = res.data as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {}
    return {};
  }

  @override
  Future<void> setPlatformEnabled(String platform, bool enabled) async {
    await setMessagingPlatformEnabled(platform, enabled);
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagingPlatforms() async {
    try {
      final res = await _dio.get("/api/messaging/platforms");
      if (res.data is Map && res.data['platforms'] is List) {
        return (res.data['platforms'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    try {
      final res = await _dio.get("/v1/platforms");
      if (res.data is Map) {
        final map = res.data as Map<String, dynamic>;
        return map.entries.map((e) => {
          'id': e.key,
          'name': e.key.isNotEmpty ? e.key[0].toUpperCase() + e.key.substring(1) : e.key,
          'enabled': e.value == true,
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<bool> setMessagingPlatformEnabled(String platformId, bool enabled) async {
    try {
      final res = await _dio.put("/api/messaging/platforms/$platformId", data: {
        "enabled": enabled,
      });
      if (res.statusCode == 200) return true;
    } catch (_) {}
    try {
      final res = await _dio.patch("/v1/platforms/$platformId", data: {"enabled": enabled});
      if (res.statusCode == 200) return true;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> updateMessagingPlatform(
    String platformId, {
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
  }) async {
    try {
      final data = <String, dynamic>{
        "enabled": ?enabled,
        if (env != null && env.isNotEmpty) "env": env,
        if (clearEnv != null && clearEnv.isNotEmpty) "clear_env": clearEnv,
      };
      final res = await _dio.put("/api/messaging/platforms/$platformId", data: data);
      if (res.statusCode == 200) return true;
    } catch (_) {}

    try {
      if (env != null) {
        for (final e in env.entries) {
          await setEnvValue(e.key, e.value);
        }
      }
      if (enabled != null) {
        await setMessagingPlatformEnabled(platformId, enabled);
      }
      return true;
    } catch (_) {}
    return false;
  }

  @override
  Future<Map<String, dynamic>?> getKanbanBoard({String? boardSlug}) async {
    try {
      final q = boardSlug != null ? {'board': boardSlug} : null;
      final res = await _dio.get("/api/plugins/kanban/board", queryParameters: q);
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      } else if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> createKanbanTask({required String title, String? body, int priority = 0, String? status}) async {
    try {
      final res = await _dio.post("/api/plugins/kanban/tasks", data: {
        "title": title,
        if (body != null && body.isNotEmpty) "body": body,
        "priority": priority,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> updateKanbanTask(String taskId, {String? status, String? title, String? body}) async {
    try {
      final data = <String, dynamic>{};
      if (status != null) data['status'] = status;
      if (title != null) data['title'] = title;
      if (body != null) data['body'] = body;
      final res = await _dio.patch("/api/plugins/kanban/tasks/$taskId", data: data);
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> deleteKanbanTask(String taskId) async {
    try {
      final res = await _dio.delete("/api/plugins/kanban/tasks/$taskId");
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> approveAction({String? requestId}) async {
    try {
      final res = await _dio.post("/api/pairing/approve", data: {
        "request_id": ?requestId,
      });
      if (res.statusCode == 200) return true;
    } catch (_) {}
    try {
      await executeSlashCommand("/approve");
      return true;
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> denyAction({String? requestId}) async {
    try {
      final res = await _dio.post("/api/pairing/revoke", data: {
        "request_id": ?requestId,
      });
      if (res.statusCode == 200) return true;
    } catch (_) {}
    try {
      await executeSlashCommand("/deny");
      return true;
    } catch (_) {}
    return false;
  }

  @override
  Future<String> readMemory() async {
    try {
      final res = await _dio.get("/api/fs/read-text?path=MEMORY.md");
      if (res.data is Map<String, dynamic> && res.data['text'] != null) {
        return res.data['text'].toString();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/memory");
      final str = res.data.toString();
      if (!str.contains('<!doctype html>') && !str.contains('<html')) return str;
    } catch (_) {}

    return '';
  }

  @override
  Future<String> readUserProfile() async {
    try {
      final res = await _dio.get("/api/fs/read-text?path=USER.md");
      if (res.data is Map<String, dynamic> && res.data['text'] != null) {
        return res.data['text'].toString();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/user/profile");
      final str = res.data.toString();
      if (!str.contains('<!doctype html>') && !str.contains('<html')) return str;
    } catch (_) {}

    return '';
  }

  @override
  Future<void> writeMemory(String content) async {
    try {
      final res = await _dio.post("/api/fs/write-text", data: {
        "path": "MEMORY.md",
        "content": content,
      });
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/memory", data: {"content": content});
    } catch (_) {}
  }

  @override
  Future<void> writeUserProfile(String content) async {
    try {
      final res = await _dio.post("/api/fs/write-text", data: {
        "path": "USER.md",
        "content": content,
      });
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/user/profile", data: {"content": content});
    } catch (_) {}
  }

  @override
  Future<String> readSoul() async {
    try {
      final res = await _dio.get("/api/profiles/default/soul");
      if (res.data is Map<String, dynamic> && res.data['content'] != null) {
        return res.data['content'].toString();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/api/fs/read-text?path=SOUL.md");
      if (res.data is Map<String, dynamic> && res.data['text'] != null) {
        return res.data['text'].toString();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/soul");
      final str = res.data.toString();
      if (!str.contains('<!doctype html>') && !str.contains('<html')) return str;
    } catch (_) {}

    return '';
  }

  @override
  Future<void> writeSoul(String content) async {
    try {
      final res = await _dio.put("/api/profiles/default/soul", data: {"content": content});
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/soul", data: {"content": content});
    } catch (_) {}
  }

  @override
  Future<Map<String, String>> readEnv() async {
    try {
      final res = await _dio.get("/v1/env");
      if (res.data is Map<String, dynamic>) {
        final map = res.data as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<void> setEnvValue(String key, String value) async {
    try {
      await _dio.put("/v1/env/$key", data: {"value": value});
    } catch (_) {}
  }

  @override
  Future<String> getConfigValue(String path) async {
    try {
      final res = await _dio.get("/api/model/info");
      if (res.data is Map<String, dynamic>) {
        final bUrl = res.data['base_url'] ?? res.data['effective_base_url'];
        if (bUrl != null && bUrl.toString().isNotEmpty) {
          return bUrl.toString();
        }
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/config/$path");
      final str = res.data.toString();
      if (!str.contains('<!doctype html>')) return str;
    } catch (_) {}
    return '';
  }

  @override
  Future<void> setConfigValue(String path, String value) async {
    try {
      String currentModel = "thinkingmachines/inkling:free";
      String currentProvider = "openrouter";
      try {
        final info = await _dio.get("/api/model/info");
        if (info.data is Map<String, dynamic>) {
          currentModel = info.data['model']?.toString() ?? currentModel;
          currentProvider = info.data['provider']?.toString() ?? currentProvider;
        }
      } catch (_) {}

      final res = await _dio.post("/api/model/set", data: {
        "scope": "main",
        "provider": currentProvider,
        "model": currentModel,
        "base_url": value,
      });
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/config/$path", data: {"value": value});
    } catch (_) {}
  }

  @override
  Stream<String> streamChat(String message, {String? model, String? sessionId}) async* {
    // 1. Try official Hermes Gateway JSON-RPC WebSocket
    final targetSession = (sessionId != null && sessionId.isNotEmpty) ? sessionId : _activeSessionId;
    final controller = StreamController<String>();
    WebSocket? ws;

    try {
      if (!_authenticated) {
        await authenticate();
      }

      String? wsTicket;
      try {
        final ticketRes = await _dio.post(
          "/api/auth/ws-ticket",
          data: {},
          options: Options(validateStatus: (s) => true),
        );
        if (ticketRes.statusCode == 200 && ticketRes.data is Map) {
          wsTicket = ticketRes.data['ticket']?.toString();
        }
      } catch (_) {}

      final String wsUri;
      if (wsTicket != null && wsTicket.isNotEmpty) {
        wsUri = '$_wsBaseUrl?ticket=$wsTicket';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=$token';
      }

      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      if (_accessToken != null) wsHeaders['Authorization'] = 'Bearer $_accessToken';

      ws = await WebSocket.connect(
        wsUri,
        headers: wsHeaders,
      ).timeout(const Duration(seconds: 10));

      if (targetSession != null) {
        _activeChatSockets[targetSession] = ws;
      }
      String? liveSessionId;
      bool hasActiveThinking = false;

      final sub = ws.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final id = parsed['id'];
            final result = parsed['result'];
            final params = parsed['params'];
            final method = parsed['method'];

            // Handle session.resume response (id: 1000)
            if (id == 1000 && result is Map<String, dynamic>) {
              liveSessionId = result['session_id'] as String?;
              _activeSessionId = result['stored_session_id'] as String? ?? targetSession;
              ws?.add(jsonEncode({
                "jsonrpc": "2.0",
                "id": 1002,
                "method": "prompt.submit",
                "params": {
                  "session_id": liveSessionId,
                  "text": message,
                },
              }));
              return;
            }

            // Handle session.create response (id: 1001)
            if (id == 1001 && result is Map<String, dynamic>) {
              liveSessionId = result['session_id'] as String?;
              _activeSessionId = result['stored_session_id'] as String?;
              ws?.add(jsonEncode({
                "jsonrpc": "2.0",
                "id": 1002,
                "method": "prompt.submit",
                "params": {
                  "session_id": liveSessionId,
                  "text": message,
                },
              }));
              return;
            }

            // Handle event notifications
            if (method == 'event' && params is Map<String, dynamic>) {
              final type = params['type'] as String?;
              final payload = params['payload'];

              // Only genuine model reasoning tokens belong in the Thought Process block
              if (type == 'reasoning.delta' && payload is Map<String, dynamic>) {
                final text = payload['text']?.toString() ?? '';
                if (text.isNotEmpty) {
                  if (!hasActiveThinking) {
                    hasActiveThinking = true;
                    controller.add('<think>$text');
                  } else {
                    controller.add(text);
                  }
                }
              } else if ((type == 'message.delta' || type == 'content.delta') && payload is Map<String, dynamic>) {
                final text = payload['text']?.toString() ?? payload['delta']?.toString() ?? '';
                if (text.isNotEmpty) {
                  if (hasActiveThinking) {
                    hasActiveThinking = false;
                    controller.add('</think>\n$text');
                  } else {
                    controller.add(text);
                  }
                }
              } else if (type == 'message.complete' || type == 'turn.finish' || type == 'turn.end') {
                if (hasActiveThinking) {
                  hasActiveThinking = false;
                  controller.add('</think>\n');
                }
                if (!controller.isClosed) {
                  controller.close();
                }
              } else if (type == 'turn.error' || type == 'error') {
                final errText = payload?.toString() ?? 'Turn error';
                if (!controller.isClosed) {
                  controller.addError(Exception(errText));
                  controller.close();
                }
              }
            }

            // RPC error
            if (parsed['error'] != null) {
              final errMap = parsed['error'];
              final errMsg = (errMap is Map) ? (errMap['message'] ?? errMap.toString()) : errMap.toString();
              if (errMsg.toLowerCase().contains("session not found")) {
                _activeSessionId = null;
                // Automatically recreate session and resubmit prompt without crashing
                ws?.add(jsonEncode({
                  "jsonrpc": "2.0",
                  "id": 1001,
                  "method": "session.create",
                  "params": {},
                }));
                return;
              }
              if (!controller.isClosed) {
                controller.addError(Exception(errMsg));
                controller.close();
              }
            }
          } catch (_) {}
        },
        onError: (err) {
          if (!controller.isClosed) {
            controller.addError(err);
            controller.close();
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      // Submit prompt: if targetSession exists, resume it! Otherwise create new session
      if (targetSession != null) {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": 1000,
          "method": "session.resume",
          "params": {"session_id": targetSession},
        }));
      } else {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": 1001,
          "method": "session.create",
          "params": {},
        }));
      }

      yield* controller.stream;
      await sub.cancel();
      await ws.close();
      return;
    } catch (e) {
      if (ws != null) {
        try { await ws.close(); } catch (_) {}
      }
      rethrow;
    } finally {
      if (targetSession != null) {
        _activeChatSockets.remove(targetSession);
      }
    }
  }

  @override
  Future<bool> stopGeneration({String? sessionId}) async {
    final sId = sessionId ?? _activeSessionId;
    bool success = false;
    try {
      final res = await callRpc("session.interrupt", sId != null ? {"session_id": sId} : {});
      success = res != null;
    } catch (e) {
      debugPrint("stopGeneration RPC error: $e");
    }

    if (sId != null && _activeChatSockets.containsKey(sId)) {
      try {
        await _activeChatSockets[sId]?.close();
      } catch (_) {}
      _activeChatSockets.remove(sId);
    }
    return success;
  }

  // -- Skills --
  @override
  Future<List<SkillInfo>> getSkills() async {
    try {
      final res = await _dio.get("/api/skills");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => SkillInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/skills");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => SkillInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<void> setSkillEnabled(String name, bool enabled) async {
    try {
      await _dio.put("/api/skills/toggle", data: {"name": name, "enabled": enabled});
      return;
    } catch (_) {}

    try {
      await _dio.patch("/v1/skills/$name", data: {"enabled": enabled});
    } catch (_) {}
  }

  // -- Toolsets --
  @override
  Future<List<ToolsetInfo>> getToolsets() async {
    try {
      final res = await _dio.get("/api/tools/toolsets");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => ToolsetInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/toolsets");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => ToolsetInfo.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getMcpServers() async {
    try {
      final res = await _dio.get("/api/mcp/servers");
      if (res.data is Map<String, dynamic>) {
        final list = res.data['servers'];
        if (list is List) {
          return list.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getMcpCatalog() async {
    try {
      final res = await _dio.get("/api/mcp/catalog");
      if (res.data is Map<String, dynamic>) {
        final entries = res.data['entries'];
        if (entries is List) {
          return entries.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        }
      } else if (res.data is List) {
        return (res.data as List).map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<bool> installMcpCatalogEntry(String name, Map<String, String> env) async {
    try {
      final res = await _dio.post("/api/mcp/catalog/install", data: {
        "name": name,
        "env": env,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> uninstallMcpServer(String name) async {
    try {
      final res = await _dio.delete("/api/mcp/servers/$name");
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setMcpServerEnabled(String name, bool enabled) async {
    try {
      final res = await _dio.put("/api/mcp/servers/$name/enabled", data: {"enabled": enabled});
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPlugins() async {
    final Map<String, Map<String, dynamic>> combined = {};

    // 1. Dashboard extensions (kanban, achievements)
    try {
      final res = await _dio.get("/api/dashboard/plugins");
      if (res.data is List) {
        for (final e in res.data) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final name = m['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              m['runtime_status'] = 'enabled';
              m['enabled'] = true;
              m['source'] = m['source'] ?? 'bundled';
              combined[name.toLowerCase()] = m;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Hub plugins (all agent plugins + orphan dashboard plugins)
    try {
      final res = await _dio.get("/api/dashboard/plugins/hub");
      if (res.data is Map<String, dynamic>) {
        final list = res.data['plugins'];
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final name = m['name']?.toString() ?? '';
              final key = name.toLowerCase();
              if (name.isNotEmpty && !combined.containsKey(key)) {
                combined[key] = m;
              }
            }
          }
        }
        final orphans = res.data['orphan_dashboard_plugins'];
        if (orphans is List) {
          for (final e in orphans) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final name = m['name']?.toString() ?? '';
              final key = name.toLowerCase();
              if (name.isNotEmpty && !combined.containsKey(key)) {
                m['runtime_status'] = 'enabled';
                m['enabled'] = true;
                combined[key] = m;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 3. Fallback to /api/plugins
    if (combined.isEmpty) {
      try {
        final res = await _dio.get("/api/plugins");
        if (res.data is List) {
          for (final e in res.data) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final name = m['name']?.toString() ?? '';
              if (name.isNotEmpty) combined[name.toLowerCase()] = m;
            }
          }
        }
      } catch (_) {}
    }

    return combined.values.toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPluginCatalog() async {
    try {
      final res = await _dio.get("/api/dashboard/plugins/catalog");
      if (res.data is Map<String, dynamic>) {
        final entries = res.data['entries'];
        if (entries is List) {
          return entries.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        }
      } else if (res.data is List) {
        return (res.data as List).map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<bool> installPlugin(String name) async {
    try {
      final res = await _dio.post("/api/dashboard/agent-plugins/install", data: {
        "catalog_name": name,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setPluginEnabled(String name, bool enabled) async {
    try {
      final action = enabled ? "enable" : "disable";
      final res = await _dio.post("/api/dashboard/agent-plugins/$name/$action");
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> uninstallPlugin(String name) async {
    try {
      final res = await _dio.delete("/api/dashboard/agent-plugins/$name");
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setToolsetEnabled(String name, bool enabled) async {
    try {
      await _dio.put("/api/tools/toolsets/$name", data: {"enabled": enabled});
      return;
    } catch (_) {}

    try {
      await _dio.put("/api/mcp/servers/$name/enabled", data: {"enabled": enabled});
      return;
    } catch (_) {}

    try {
      await _dio.patch("/v1/toolsets/$name", data: {"enabled": enabled});
    } catch (_) {}
  }
  // -- Models --
  @override
  Future<List<ModelConfig>> getModels() async {
    try {
      final res = await _dio.get("/api/model/options");
      if (res.data is Map<String, dynamic>) {
        final currentModel = res.data['model'] as String? ?? 'hermes-agent';
        final currentProvider = res.data['provider'] as String? ?? 'openrouter';
        final providers = (res.data['providers'] as List<dynamic>?) ?? [];
        final List<ModelConfig> result = [];
        for (final p in providers) {
          if (p is Map<String, dynamic>) {
            final pName = p['name'] as String? ?? p['slug'] as String? ?? 'openrouter';
            final rawModels = p['models'];
            final List<String> modelNames = [];
            if (rawModels is List) {
              modelNames.addAll(rawModels.map((e) => e.toString()));
            } else if (rawModels is String) {
              modelNames.addAll(rawModels.split(RegExp(r'\s+')).where((s) => s.isNotEmpty));
            }
            for (final m in modelNames) {
              result.add(ModelConfig(
                name: m,
                provider: pName,
                model: m,
                baseUrl: '',
                enabled: m == currentModel,
              ));
            }
          }
        }
        if (result.isNotEmpty) {
          if (!result.any((m) => m.name == currentModel)) {
            result.insert(0, ModelConfig(
              name: currentModel,
              provider: currentProvider,
              model: currentModel,
              baseUrl: '',
              enabled: true,
            ));
          }
          return result;
        }
      }
    } catch (_) {}

    try {
      final info = await _dio.get("/api/model/info");
      if (info.data is Map<String, dynamic>) {
        final currentModel = info.data['model'] as String? ?? 'hermes-agent';
        final currentProvider = info.data['provider'] as String? ?? 'openrouter';
        return [
          ModelConfig(
            name: currentModel,
            provider: currentProvider,
            model: currentModel,
            baseUrl: '',
            enabled: true,
          )
        ];
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/models");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => ModelConfig.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
  @override
  Future<void> setModelEnabled(String name, bool enabled) async {
    try {
      final res = await _dio.post("/api/model/set", data: {
        "scope": "main",
        "provider": "openrouter",
        "model": name,
      });
      if (res.statusCode == 200) return;
    } catch (_) {}
    try {
      await _dio.patch("/v1/models/$name", data: {"enabled": enabled});
    } catch (_) {}
  }
  @override
  Future<void> setModelProviderKey(String modelName, String provider, String key) async {
    try {
      final res = await _dio.post("/api/model/set", data: {
        "scope": "main",
        "provider": provider.isEmpty || provider == 'default' ? 'openrouter' : provider,
        "model": modelName.isEmpty || modelName == 'hermes-agent' ? 'thinkingmachines/inkling:free' : modelName,
        "api_key": key,
      });
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/models/$modelName/provider", data: {"provider": provider, "api_key": key});
    } catch (_) {}
  }
  // -- Sessions --
  @override
  Future<List<SessionSummary>> getSessions({String? query}) async {
    final qp = query != null ? "?q=$query" : "";
    try {
      final res = await _dio.get("/api/sessions$qp");
      if (res.data is Map<String, dynamic>) {
        final list = (res.data['sessions'] as List<dynamic>?) ?? [];
        return list.map((j) => SessionSummary.fromJson(j as Map<String, dynamic>)).toList();
      } else if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/sessions$qp");
      if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>))
            .toList();
      } else if (res.data is Map<String, dynamic>) {
        final list = (res.data['sessions'] as List<dynamic>?) ?? [];
        return list.map((j) => SessionSummary.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return [];
  }
  @override
  Future<void> deleteSession(String id) async {
    try {
      final res = await _dio.delete("/api/sessions/$id");
      if (res.statusCode == 200) return;
    } catch (_) {}
    try {
      await _dio.delete("/v1/sessions/$id");
    } catch (_) {}
  }

  @override
  Future<void> renameSession(String id, String newTitle) async {
    try {
      await _dio.patch("/api/sessions/$id", data: {'title': newTitle});
      return;
    } catch (_) {}
    try {
      await _dio.put("/api/sessions/$id", data: {'title': newTitle});
      return;
    } catch (_) {}
    try {
      await _dio.patch("/v1/sessions/$id", data: {'title': newTitle});
    } catch (_) {}
  }
  // -- Schedules --
  @override
  Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final res = await _dio.get("/api/cron/jobs");
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      if (raw is List) {
        return raw.map((e) {
          final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};
          final cronExpr = m['schedule_display'] ??
              (m['schedule'] is Map ? m['schedule']['expr'] : m['schedule']) ??
              m['cron'] ??
              '';
          m['cron'] = cronExpr;
          m['target'] = m['prompt'] ?? m['target'] ?? '';
          if (m['enabled'] == null && m['paused'] != null) {
            m['enabled'] = m['paused'] != true;
          }
          return m;
        }).toList();
      }
    } catch (_) {}
    try {
      final res = await _dio.get("/v1/schedules");
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      if (raw is List) {
        return raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      }
    } catch (_) {}
    return [];
  }
  @override
  Future<void> createSchedule(Map<String, dynamic> schedule) async {
    final cronExpr = schedule['schedule'] ?? schedule['cron'] ?? '* * * * *';
    final prompt = schedule['prompt'] ?? schedule['target'] ?? '';
    final name = schedule['name'] ?? '';
    final isEnabled = schedule['enabled'] != false;

    final payload = {
      'name': name,
      'schedule': cronExpr,
      'prompt': prompt,
      'paused': !isEnabled,
      'deliver': 'local',
      if (schedule['model'] != null) 'model': schedule['model'],
      if (schedule['provider'] != null) 'provider': schedule['provider'],
      if (schedule['skills'] != null) 'skills': schedule['skills'],
      if (schedule['enabled_toolsets'] != null) 'enabled_toolsets': schedule['enabled_toolsets'],
    };

    final res = await _dio.post("/api/cron/jobs", data: payload);
    if (res.statusCode == 200 || res.statusCode == 201) return;
    throw Exception("Failed to create cron job: ${res.statusCode}");
  }
  @override
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule) async {
    final cronExpr = schedule['schedule'] ?? schedule['cron'] ?? '* * * * *';
    final prompt = schedule['prompt'] ?? schedule['target'] ?? '';
    final name = schedule['name'] ?? '';
    final isEnabled = schedule['enabled'] != false;

    final payload = {
      'name': name,
      'schedule': cronExpr,
      'prompt': prompt,
      'paused': !isEnabled,
      if (schedule['model'] != null) 'model': schedule['model'],
      if (schedule['provider'] != null) 'provider': schedule['provider'],
      if (schedule['skills'] != null) 'skills': schedule['skills'],
      if (schedule['enabled_toolsets'] != null) 'enabled_toolsets': schedule['enabled_toolsets'],
    };

    final res = await _dio.put("/api/cron/jobs/$id", data: {"updates": payload});
    if (res.statusCode == 200) return;
    throw Exception("Failed to update cron job: ${res.statusCode}");
  }
  @override
  Future<void> deleteSchedule(String id) async {
    final res = await _dio.delete("/api/cron/jobs/$id");
    if (res.statusCode == 200) return;
    throw Exception("Failed to delete cron job: ${res.statusCode}");
  }
  // -- Settings --
  @override
  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get("/v1/settings");
    return res.data as Map<String, dynamic>;
  }
  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _dio.put("/v1/settings", data: settings);
  }
  // -- Plugins & Extensions --
  @override
  Future<Map<String, dynamic>?> getPluginApi(String pluginName, String path) async {
    try {
      final p = path.startsWith('/') ? path.substring(1) : path;
      final res = await _dio.get("/api/plugins/$pluginName/$p");
      if (res.statusCode == 200) {
        if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
        if (res.data is List) return {"items": res.data};
      }
    } catch (_) {}
    return null;
  }

  // -- Slash Command Execution via WebSocket / JSON-RPC --
  @override
  Future<String> executeSlashCommand(String command, {String? sessionId}) async {
    final cleanCmd = command.trim();
    if (cleanCmd.isEmpty) return "No command provided.";

    try {
      if (!_authenticated) {
        await authenticate();
      }

      String? wsTicket;
      try {
        final ticketRes = await _dio.post(
          "/api/auth/ws-ticket",
          data: {},
          options: Options(validateStatus: (s) => true),
        );
        if (ticketRes.statusCode == 200 && ticketRes.data is Map) {
          wsTicket = ticketRes.data['ticket']?.toString();
        }
      } catch (_) {}

      final String wsUri;
      if (wsTicket != null && wsTicket.isNotEmpty) {
        wsUri = '$_wsBaseUrl?ticket=$wsTicket';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=$token';
      }

      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      if (_accessToken != null) wsHeaders['Authorization'] = 'Bearer $_accessToken';

      final ws = await WebSocket.connect(
        wsUri,
        headers: wsHeaders,
      ).timeout(const Duration(seconds: 8));

      final completer = Completer<String>();
      final targetSession = (sessionId != null && sessionId.isNotEmpty) ? sessionId : _activeSessionId;
      String? liveSessionId;

      StreamSubscription? sub;
      Timer? timeoutTimer;

      void finish(String res) {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          sub?.cancel();
          try {
            ws.close();
          } catch (_) {}
          completer.complete(res);
        }
      }

      timeoutTimer = Timer(const Duration(seconds: 20), () {
        finish("Command execution timed out after 20 seconds.");
      });

      sub = ws.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final id = parsed['id'];
            final result = parsed['result'];
            final error = parsed['error'];

            // 1. Session resume or start response
            if ((id == 1000 || id == 1001) && result is Map<String, dynamic>) {
              liveSessionId = result['session_id'] as String?;
              _activeSessionId = result['stored_session_id'] as String? ?? targetSession;

              ws.add(jsonEncode({
                "jsonrpc": "2.0",
                "id": 2000,
                "method": "slash.exec",
                "params": {
                  "session_id": liveSessionId,
                  "command": cleanCmd,
                }
              }));
            } else if ((id == 1000 || id == 1001) && error != null) {
              // Failed to resume session, try start new session
              ws.add(jsonEncode({
                "jsonrpc": "2.0",
                "id": 1002,
                "method": "session.start",
                "params": {}
              }));
            } else if (id == 1002 && result is Map<String, dynamic>) {
              liveSessionId = result['session_id'] as String?;
              ws.add(jsonEncode({
                "jsonrpc": "2.0",
                "id": 2000,
                "method": "slash.exec",
                "params": {
                  "session_id": liveSessionId,
                  "command": cleanCmd,
                }
              }));
            }

            // 2. slash.exec response (id: 2000)
            if (id == 2000) {
              if (result is Map<String, dynamic>) {
                final out = result['output']?.toString();
                finish(out ?? "Command executed successfully.");
                return;
              }

              if (error is Map<String, dynamic>) {
                final code = error['code'];
                if (code == 4018) {
                  final raw = cleanCmd.replaceFirst(RegExp(r'^/'), '');
                  final parts = raw.split(RegExp(r'\s+'));
                  final name = parts.isNotEmpty ? parts[0] : '';
                  final arg = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                  ws.add(jsonEncode({
                    "jsonrpc": "2.0",
                    "id": 2001,
                    "method": "command.dispatch",
                    "params": {
                      "session_id": liveSessionId,
                      "name": name,
                      "arg": arg,
                    }
                  }));
                  return;
                }
                finish("Error: ${error['message'] ?? error.toString()}");
                return;
              }
              if (result != null) {
                finish(result.toString());
                return;
              }
            }

            // 3. command.dispatch response (id: 2001)
            if (id == 2001) {
              if (result is Map<String, dynamic>) {
                final out = result['output'] ?? result['message'] ?? result['status'] ?? result.toString();
                finish(out.toString());
                return;
              }
              if (error != null) {
                finish("Error: ${error['message'] ?? error.toString()}");
                return;
              }
              finish(result?.toString() ?? "Command executed.");
            }
          } catch (e) {
            finish("Error parsing command output: $e");
          }
        },
        onError: (e) {
          finish("WebSocket error: $e");
        },
        onDone: () {
          if (!completer.isCompleted) {
            finish("Connection closed before response received.");
          }
        },
      );

      // Trigger handshake
      if (targetSession != null && targetSession.isNotEmpty && !targetSession.startsWith("temp_")) {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": 1000,
          "method": "session.resume",
          "params": {"session_id": targetSession}
        }));
      } else {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": 1001,
          "method": "session.start",
          "params": {}
        }));
      }

      return await completer.future;
    } catch (e) {
      return "Failed to execute command: $e";
    }
  }

  Future<dynamic> callRpc(String method, [Map<String, dynamic>? params]) async {
    try {
      if (!_authenticated) {
        await authenticate();
      }

      String? wsTicket;
      try {
        final ticketRes = await _dio.post(
          "/api/auth/ws-ticket",
          data: {},
          options: Options(validateStatus: (s) => true),
        );
        if (ticketRes.statusCode == 200 && ticketRes.data is Map) {
          wsTicket = ticketRes.data['ticket']?.toString();
        }
      } catch (_) {}

      final String wsUri;
      if (wsTicket != null && wsTicket.isNotEmpty) {
        wsUri = '$_wsBaseUrl?ticket=$wsTicket';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=$token';
      }

      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      if (_accessToken != null) wsHeaders['Authorization'] = 'Bearer $_accessToken';

      final ws = await WebSocket.connect(
        wsUri,
        headers: wsHeaders,
      ).timeout(const Duration(seconds: 8));

      final completer = Completer<dynamic>();
      StreamSubscription? sub;
      Timer? timeoutTimer;

      void finish(dynamic val, [bool isError = false]) {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          sub?.cancel();
          try { ws.close(); } catch (_) {}
          if (isError) {
            completer.completeError(val);
          } else {
            completer.complete(val);
          }
        }
      }

      timeoutTimer = Timer(const Duration(seconds: 10), () {
        finish(TimeoutException("RPC method '$method' timed out after 10s"), true);
      });

      const reqId = 7701;
      ws.add(jsonEncode({
        "jsonrpc": "2.0",
        "id": reqId,
        "method": method,
        "params": params ?? {},
      }));

      sub = ws.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final id = parsed['id'];
            if (id == reqId) {
              if (parsed['error'] != null) {
                finish(Exception(parsed['error'].toString()), true);
              } else {
                finish(parsed['result']);
              }
            }
          } catch (e) {
            finish(e, true);
          }
        },
        onError: (err) => finish(err, true),
        onDone: () {
          if (!completer.isCompleted) finish(null);
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint("callRpc error for $method: $e");
      return null;
    }
  }

  @override
  Future<String> getReasoningEffort() async {
    try {
      final res = await callRpc("config.get", {"key": "reasoning"});
      if (res is Map) {
        final val = res['value']?.toString().toLowerCase() ?? 'low';
        return val;
      }
    } catch (_) {}
    return 'low';
  }

  @override
  Future<bool> setReasoningEffort(String effort) async {
    try {
      final res = await callRpc("config.set", {
        "key": "reasoning",
        "value": effort,
        "scope": "global",
      });
      return res != null;
    } catch (_) {}
    return false;
  }

  @override
  Future<String?> getActiveWorkspaceCwd() async {
    // 1. Try JSON-RPC config.get cwd or fs.pwd
    try {
      final res = await callRpc("config.get", {"key": "cwd"});
      if (res is Map && res['value'] != null) {
        return res['value'].toString();
      }
      if (res is String && res.isNotEmpty) return res;
    } catch (_) {}

    try {
      final res = await callRpc("fs.pwd", {});
      if (res is Map && res['cwd'] != null) return res['cwd'].toString();
      if (res is String && res.isNotEmpty) return res;
    } catch (_) {}

    // 2. Try HTTP /api/status with deep parsing
    try {
      final res = await _dio.get("/api/status");
      if (res.data is Map) {
        final d = res.data as Map;
        final candidate = d['cwd'] ??
            (d['workspace'] is String ? d['workspace'] : null) ??
            (d['workspace'] is Map ? (d['workspace']['path'] ?? d['workspace']['cwd'] ?? d['workspace']['root']) : null) ??
            (d['system'] is Map ? (d['system']['cwd'] ?? d['system']['workspace']) : null) ??
            (d['daemon'] is Map ? (d['daemon']['cwd'] ?? d['daemon']['workspace']) : null) ??
            (d['data'] is Map ? (d['data']['cwd'] ?? d['data']['workspace']) : null) ??
            (d['config'] is Map ? (d['config']['cwd'] ?? d['config']['workspace']) : null) ??
            d['workspace_dir'] ??
            d['project_path'] ??
            d['active_workspace'] ??
            d['root'];
        if (candidate != null && candidate.toString().isNotEmpty) {
          return candidate.toString();
        }
      }
    } catch (_) {}

    // 3. Try HTTP /api/workspace
    try {
      final res = await _dio.get("/api/workspace");
      if (res.data is Map) {
        final d = res.data as Map;
        final candidate = d['path'] ?? d['cwd'] ?? d['workspace'] ?? d['root'];
        if (candidate != null && candidate.toString().isNotEmpty) {
          return candidate.toString();
        }
      }
    } catch (_) {}

    // 4. Try HTTP /api/fs/list
    try {
      final res = await _dio.get("/api/fs/list", queryParameters: {"path": "."});
      if (res.data is Map) {
        final d = res.data as Map;
        final candidate = d['cwd'] ?? d['path'] ?? d['root'] ?? d['dir'];
        if (candidate != null && candidate.toString().isNotEmpty) {
          return candidate.toString();
        }
      }
    } catch (_) {}

    // 5. Try /v1/env or /v1/config/cwd
    try {
      final env = await readEnv();
      final envCwd = env['HERMES_WORKSPACE'] ?? env['HERMES_CWD'] ?? env['WORKSPACE'] ?? env['PWD'] ?? env['CWD'];
      if (envCwd != null && envCwd.isNotEmpty) {
        return envCwd;
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/config/cwd");
      if (res.data is Map && res.data['value'] != null) {
        return res.data['value'].toString();
      }
      if (res.data is String && res.data.toString().isNotEmpty && !res.data.toString().contains('<html')) {
        return res.data.toString();
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<bool> setActiveWorkspaceCwd(String path) async {
    try {
      final res = await callRpc("config.set", {
        "key": "cwd",
        "value": path,
      });
      return res != null;
    } catch (_) {}
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getProjectsList() async {
    try {
      final res = await callRpc("projects.list", {});
      if (res is Map && res['projects'] is List) {
        return List<Map<String, dynamic>>.from(res['projects'] as List);
      }
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> listWorkspaceFiles({String? subpath}) async {
    final targetPath = subpath ?? '.';
    // 1. Try JSON-RPC fs.list
    try {
      final rpcRes = await callRpc("fs.list", {"path": targetPath});
      if (rpcRes is List) {
        return List<Map<String, dynamic>>.from(rpcRes);
      }
      if (rpcRes is Map && rpcRes['files'] is List) {
        return List<Map<String, dynamic>>.from(rpcRes['files'] as List);
      }
      if (rpcRes is Map && rpcRes['entries'] is List) {
        return List<Map<String, dynamic>>.from(rpcRes['entries'] as List);
      }
    } catch (_) {}

    // 2. Try HTTP /api/fs/list
    try {
      final res = await _dio.get("/api/fs/list", queryParameters: {"path": targetPath});
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data as List);
      }
      if (res.data is Map && res.data['files'] is List) {
        return List<Map<String, dynamic>>.from(res.data['files'] as List);
      }
      if (res.data is Map && res.data['entries'] is List) {
        return List<Map<String, dynamic>>.from(res.data['entries'] as List);
      }
    } catch (_) {}

    // Try without path parameter
    try {
      final res = await _dio.get("/api/fs/list");
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data as List);
      }
      if (res.data is Map && res.data['files'] is List) {
        return List<Map<String, dynamic>>.from(res.data['files'] as List);
      }
    } catch (_) {}

    // 3. Try HTTP /api/fs/tree
    try {
      final res = await _dio.get("/api/fs/tree", queryParameters: {"path": targetPath});
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data as List);
      }
      if (res.data is Map && res.data['entries'] is List) {
        return List<Map<String, dynamic>>.from(res.data['entries'] as List);
      }
    } catch (_) {}

    // 4. Try /api/workspace/files
    try {
      final res = await _dio.get("/api/workspace/files");
      if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data as List);
      }
      if (res.data is Map && res.data['files'] is List) {
        return List<Map<String, dynamic>>.from(res.data['files'] as List);
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<String?> readWorkspaceFile(String path) async {
    final normalizedPath = path.replaceAll('\\', '/');

    // 1. Try HTTP /api/fs/read-text with both raw and normalized paths
    for (final p in [path, normalizedPath]) {
      try {
        final res = await _dio.get("/api/fs/read-text", queryParameters: {"path": p});
        if (res.data is Map<String, dynamic>) {
          final content = res.data['text'] ?? res.data['content'] ?? res.data['data'];
          if (content != null) return content.toString();
        }
        if (res.data is String && !res.data.toString().contains('<!doctype html>')) {
          return res.data.toString();
        }
      } catch (_) {}
    }

    // 2. Try HTTP /api/fs/read
    for (final p in [path, normalizedPath]) {
      try {
        final res = await _dio.get("/api/fs/read", queryParameters: {"path": p});
        if (res.data is Map<String, dynamic>) {
          final content = res.data['content'] ?? res.data['text'] ?? res.data['data'];
          if (content != null) return content.toString();
        }
        if (res.data is String && !res.data.toString().contains('<!doctype html>')) {
          return res.data.toString();
        }
      } catch (_) {}
    }

    // 3. Try JSON-RPC fs.read & fs.readText
    try {
      final rpcRes = await callRpc("fs.read", {"path": path});
      if (rpcRes is Map && rpcRes['content'] != null) {
        return rpcRes['content'].toString();
      }
      if (rpcRes is String) return rpcRes;
    } catch (_) {}

    try {
      final rpcRes = await callRpc("fs.readText", {"path": path});
      if (rpcRes is Map && rpcRes['text'] != null) {
        return rpcRes['text'].toString();
      }
      if (rpcRes is String) return rpcRes;
    } catch (_) {}

    return null;
  }

  @override
  void dispose() {}
}
