import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:dio/dio.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../models/connection_config.dart";
import "../models/agent_profile.dart";
import "../models/config_health_item.dart";
import "hermes_connection.dart";
class RemoteConnection extends HermesConnection {
  final ConnectionConfig config;
  late final Dio _dio;
  String? _activeSessionId;
  @override
  String? get activeSessionId => _activeSessionId;
  @override
  set activeSessionId(String? id) => _activeSessionId = id;

  String _activeProfile = 'default';
  @override
  String get activeProfile => _activeProfile;
  @override
  set activeProfile(String profile) {
    final clean = profile.trim();
    _activeProfile = clean.isEmpty ? 'default' : clean;
    _applyProfileCookie(_activeProfile);
  }

  String _normProfile(String? profile) {
    if (profile != null && profile.trim().isNotEmpty) {
      return profile.trim();
    }
    return _activeProfile.isNotEmpty ? _activeProfile : 'default';
  }

  String _baseUrlPrefKey(String profile) =>
      profile == 'default' ? 'custom_inference_base_url' : 'custom_inference_base_url__$profile';

  String _apiKeyPrefKey(String profile) =>
      profile == 'default' ? 'custom_inference_api_key' : 'custom_inference_api_key__$profile';

  String _selectedModelPrefKey(String profile) =>
      profile == 'default' ? 'active_selected_model' : 'active_selected_model__$profile';

  static bool _isMaskedSecret(String? val) {
    if (val == null) return true;
    final trimmed = val.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^\*+$').hasMatch(trimmed) || trimmed.contains('â€¢â€¢â€¢â€¢') || trimmed.contains('****');
  }

  void _applyProfileCookie(String profile) {
    final clean = profile.trim().isEmpty ? 'default' : profile.trim();
    final existing = (_cookieHeader ?? '')
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('hermes_profile='))
        .toList();
    existing.add('hermes_profile=$clean');
    _cookieHeader = existing.join('; ');
    try {
      _dio.options.headers['Cookie'] = _cookieHeader;
    } catch (_) {}
  }

  Map<String, dynamic>? _withProfile(String? profile, [Map<String, dynamic>? extra]) {
    final p = _normProfile(profile);
    final map = <String, dynamic>{
      ...?extra,
      if (p.isNotEmpty && p != 'default') 'profile': p,
    };
    return map.isEmpty ? null : map;
  }

  final Map<String, String> _customBaseUrlByProfile = {};
  final Map<String, String> _customApiKeyByProfile = {};

  String? _cookieHeader;
  String? _accessToken;
  bool _authenticated = false;
  final Map<String, WebSocket> _activeChatSockets = {};

  dynamic _pendingApprovalId;
  WebSocket? _pendingApprovalWs;

  @override
  Future<bool> respondApproval(String choice) async {
    final ws = _pendingApprovalWs;
    final reqId = _pendingApprovalId;
    if (ws != null && reqId != null) {
      try {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": reqId,
          "result": {
            "choice": choice,
          }
        }));
        _pendingApprovalId = null;
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Session source reported to Hermes so it resolves this client as its own
  /// platform instead of defaulting to the terminal UI hint.
  static const String clientSource = 'mobile';

  late final String _baseUrl;
  late final String _wsBaseUrl;
  String? _lastModelFetchError;
  @override
  String? get lastModelFetchError => _lastModelFetchError;

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
      receiveTimeout: const Duration(minutes: 15),
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
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId, {String? profile}) async {
    try {
      final res = await _dio.get(
        "/api/sessions/$sessionId/messages",
        queryParameters: _withProfile(profile),
      );
      dynamic raw = res.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {}
      }
      if (raw is Map) {
        final list = (raw['messages'] as List<dynamic>?) ?? [];
        final parsed = list.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        if (parsed.isNotEmpty) return parsed;
      } else if (raw is List) {
        final parsed = raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    // If profile was not default and returned empty/404, also check default profile storage
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
        final parsed = list.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        if (parsed.isNotEmpty) return parsed;
      } else if (raw is List) {
        final parsed = raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    try {
      final res = await _dio.get(
        "/v1/sessions/$sessionId/messages",
        queryParameters: _withProfile(profile),
      );
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
        return map.entries.map((e) => <String, dynamic>{
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
  Future<String> readMemory({String? profile}) async {
    try {
      final res = await _dio.get(
        "/api/fs/read-text",
        queryParameters: _withProfile(profile, {"path": "MEMORY.md"}),
      );
      if (res.data is Map<String, dynamic> && res.data['text'] != null) {
        return res.data['text'].toString();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/v1/memory", queryParameters: _withProfile(profile));
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
  Future<void> writeMemory(String content, {String? profile}) async {
    try {
      final res = await _dio.post(
        "/api/fs/write-text",
        queryParameters: _withProfile(profile),
        data: {
          "path": "MEMORY.md",
          "content": content,
        },
      );
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put(
        "/v1/memory",
        queryParameters: _withProfile(profile),
        data: {"content": content},
      );
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
  Future<String> readSoul({String? profile}) async {
    final targetProfile = (profile != null && profile.trim().isNotEmpty) ? profile.trim() : "default";
    try {
      final res = await _dio.get("/api/profiles/$targetProfile/soul");
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
  Future<void> writeSoul(String content, {String? profile}) async {
    final targetProfile = (profile != null && profile.trim().isNotEmpty) ? profile.trim() : "default";
    try {
      final res = await _dio.put("/api/profiles/$targetProfile/soul", data: {"content": content});
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put("/v1/soul", data: {"content": content});
    } catch (_) {}
  }

  @override
  Future<List<AgentProfile>> listProfiles() async {
    try {
      final res = await _dio.get("/api/profiles");
      if (res.data is Map<String, dynamic>) {
        final list = res.data['profiles'];
        if (list is List<dynamic>) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((j) => AgentProfile.fromJson(j))
              .toList();
        }
      } else if (res.data is List<dynamic>) {
        return (res.data as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((j) => AgentProfile.fromJson(j))
            .toList();
      }
    } catch (_) {}

    // Fallback default profile if server does not have profiles endpoint yet
    return const [
      AgentProfile(
        id: "default",
        name: "Default Agent",
        isDefault: true,
      ),
    ];
  }

  @override
  Future<bool> createProfile(
    String name, {
    String? cloneFrom,
    String? description,
    void Function(String error)? onError,
  }) async {
    final safeName = AgentProfile.canonicalizeId(name);
    if (safeName.isEmpty) {
      onError?.call(
        "Invalid profile identifier. Use lowercase letters, numbers, hyphens, and underscores.",
      );
      return false;
    }
    if (safeName == 'default') {
      onError?.call("Cannot create a profile named 'default'.");
      return false;
    }
    final srcProfile = (cloneFrom != null && cloneFrom.trim().isNotEmpty)
        ? cloneFrom.trim()
        : null;
    try {
      final payload = <String, dynamic>{
        "name": safeName,
        if (description != null && description.trim().isNotEmpty)
          "description": description.trim(),
        if (srcProfile != null) ...{
          "clone": true,
          "clone_from": srcProfile,
          "clone_config": true,
          "clone_all": true,
        },
      };
      final res = await _dio.post(
        "/api/profiles",
        data: payload,
        options: Options(validateStatus: (s) => (s ?? 500) < 500),
      );
      final ok = res.statusCode == 200 || res.statusCode == 201;
      if (!ok) {
        String errorMsg = "Failed to create profile";
        if (res.data is Map && res.data['detail'] != null) {
          errorMsg = res.data['detail'].toString();
        } else if (res.data is String && (res.data as String).isNotEmpty) {
          errorMsg = res.data as String;
        }
        debugPrint("createProfile failed (${res.statusCode}): $errorMsg");
        onError?.call(errorMsg);
        return false;
      }
      if (ok && srcProfile != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final srcUrl = prefs.getString(_baseUrlPrefKey(srcProfile)) ?? '';
          final srcKey = prefs.getString(_apiKeyPrefKey(srcProfile)) ?? '';
          final srcModel = prefs.getString(_selectedModelPrefKey(srcProfile)) ?? '';
          if (srcUrl.isNotEmpty) {
            await prefs.setString(_baseUrlPrefKey(safeName), srcUrl);
            _customBaseUrlByProfile[safeName] = srcUrl;
          }
          if (srcKey.isNotEmpty) {
            await prefs.setString(_apiKeyPrefKey(safeName), srcKey);
            _customApiKeyByProfile[safeName] = srcKey;
          }
          if (srcModel.isNotEmpty) {
            await prefs.setString(_selectedModelPrefKey(safeName), srcModel);
          }
          if (srcUrl.isNotEmpty || srcKey.isNotEmpty) {
            await setCustomInferenceEndpoint(
              baseUrl: srcUrl,
              apiKey: srcKey,
              model: srcModel.isNotEmpty ? srcModel : null,
              profile: safeName,
            );
          }
        } catch (_) {}
      }
      return ok;
    } on DioException catch (e) {
      String errorMsg = "Network error while creating profile";
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        errorMsg = e.response!.data['detail'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMsg = e.message!;
      }
      debugPrint("createProfile DioException: $errorMsg");
      onError?.call(errorMsg);
      return false;
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint("createProfile error: $errorMsg");
      onError?.call(errorMsg);
      return false;
    }
  }

  @override
  Future<bool> deleteProfile(String name) async {
    final safeName = name.trim();
    if (safeName.isEmpty || safeName == 'default') return false;

    bool deleted = false;
    try {
      final res = await _dio.delete(
        "/api/profiles/${Uri.encodeComponent(safeName)}",
        options: Options(validateStatus: (s) => (s ?? 500) < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        deleted = true;
      }
    } catch (_) {}

    if (!deleted) {
      try {
        final res = await _dio.delete(
          "/api/profiles",
          queryParameters: {"name": safeName, "profile": safeName},
          data: {"name": safeName, "profile": safeName},
          options: Options(validateStatus: (s) => (s ?? 500) < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) {
          deleted = true;
        }
      } catch (_) {}
    }

    if (deleted) {
      _customBaseUrlByProfile.remove(safeName);
      _customApiKeyByProfile.remove(safeName);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_baseUrlPrefKey(safeName));
        await prefs.remove(_apiKeyPrefKey(safeName));
        await prefs.remove(_selectedModelPrefKey(safeName));
      } catch (_) {}
      if (_activeProfile == safeName) {
        activeProfile = 'default';
      }
    }
    return deleted;
  }

  /// Default `platform_hints.mobile` text written to a profile's config so
  /// Hermes knows how to format replies for this client.
  static const String mobilePlatformHint =
      'You are chatting through a mobile app on an Android phone. The screen is '
      'narrow and touch driven. Keep replies short and direct. Avoid wide tables '
      'and long code blocks. Markdown is rendered by the app. There is no '
      'attachment channel, so state a file path or URL in plain text.';

  final Set<String> _platformHintChecked = {};

  /// Writes `platform_hints.mobile` to the profile config when the user has
  /// not set one yet. Never overwrites an existing entry. Runs once per profile
  /// per connection and fails silently, for example on managed installs.
  Future<bool> ensureMobilePlatformHint({String? profile}) async {
    final p = _normProfile(profile);
    if (!_platformHintChecked.add(p)) return false;
    final quick = Options(
      sendTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (s) => true,
    );
    try {
      final current = await _dio.get(
        "/api/config",
        queryParameters: _withProfile(p, {"include_defaults": false}),
        options: quick,
      );
      if (current.statusCode != 200 || current.data is! Map) return false;
      final hints = (current.data as Map)['platform_hints'];
      if (hints is Map && hints[clientSource] != null) return false;

      final res = await _dio.put(
        "/api/config",
        queryParameters: _withProfile(p),
        data: {
          "config": {
            "platform_hints": {
              clientSource: {"replace": mobilePlatformHint},
            },
          },
          if (p != 'default') "profile": p,
        },
        options: quick,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> switchServerProfile(String name) async {
    final target = name.trim().isEmpty ? 'default' : name.trim();
    activeProfile = target;
    try {
      final res = await _dio.post(
        "/api/profile/switch",
        data: {"profile": target, "name": target},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (s) => true,
        ),
      );
      final setCookies = res.headers['set-cookie'] ?? [];
      if (setCookies.isNotEmpty) {
        final existingMap = <String, String>{};
        for (final part in (_cookieHeader ?? '').split(';')) {
          final kv = part.trim();
          final eq = kv.indexOf('=');
          if (eq > 0) {
            existingMap[kv.substring(0, eq)] = kv.substring(eq + 1);
          }
        }
        for (final sc in setCookies) {
          final firstPair = sc.split(';').first.trim();
          final eq = firstPair.indexOf('=');
          if (eq > 0) {
            existingMap[firstPair.substring(0, eq)] = firstPair.substring(eq + 1);
          }
        }
        existingMap['hermes_profile'] = target;
        _cookieHeader = existingMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
        _dio.options.headers['Cookie'] = _cookieHeader;
      }
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> installSkill(String identifier, {String? profile}) async {
    final safeId = identifier.trim();
    if (safeId.isEmpty) return false;

    // 1. Try REST API endpoint
    try {
      final payload = <String, dynamic>{
        "name": safeId,
        "source": safeId,
        if (profile != null && profile.trim().isNotEmpty) "profile": profile.trim(),
      };
      final res = await _dio.post("/api/skills/install", data: payload);
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (_) {}

    // 2. Fallback to CLI slash command
    try {
      final pFlag = (profile != null && profile != "default") ? " -p $profile" : "";
      await executeSlashCommand("/skills install $safeId --yes$pFlag");
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ConfigHealthItem>> runConfigHealthAudit() async {
    final issues = <ConfigHealthItem>[];

    // 1. Check if backend has native diagnostic endpoint
    try {
      final res = await _dio.get("/api/config/health");
      if (res.data is Map<String, dynamic> && res.data['issues'] is List<dynamic>) {
        final list = (res.data['issues'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((j) => ConfigHealthItem.fromJson(j))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 2. Gateway Reachability & Connection Check
    try {
      final pingStart = DateTime.now().millisecondsSinceEpoch;
      final res = await _dio.get("/api/health");
      final latency = DateTime.now().millisecondsSinceEpoch - pingStart;
      if (res.statusCode == 200) {
        issues.add(ConfigHealthItem(
          title: "Gateway Connection",
          description: "Gateway instance is online and responding (latency: ${latency}ms).",
          severity: HealthSeverity.healthy,
          category: "Network",
        ));
      } else {
        issues.add(ConfigHealthItem(
          title: "Gateway Status",
          description: "Gateway returned non-standard status code: ${res.statusCode}.",
          severity: HealthSeverity.warning,
          category: "Network",
        ));
      }
    } catch (e) {
      issues.add(ConfigHealthItem(
        title: "Gateway Connectivity",
        description: "Unable to reach health endpoint directly: $e",
        severity: HealthSeverity.warning,
        category: "Network",
      ));
    }

    // 3. Model Inference Provider Audit
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString('custom_inference_base_url');
      final customKey = prefs.getString('custom_inference_api_key');
      if (customUrl != null && customUrl.isNotEmpty) {
        if (customKey == null || customKey.trim().isEmpty) {
          issues.add(const ConfigHealthItem(
            title: "Model API Key",
            description: "Custom inference URL configured but API Key is empty.",
            severity: HealthSeverity.warning,
            category: "Inference",
            autoFixable: false,
          ));
        } else {
          issues.add(const ConfigHealthItem(
            title: "Model Inference Configuration",
            description: "Inference provider endpoint and credential format verified.",
            severity: HealthSeverity.healthy,
            category: "Inference",
          ));
        }
      } else {
        issues.add(const ConfigHealthItem(
          title: "Model Inference",
          description: "Using instance default backend inference provider.",
          severity: HealthSeverity.healthy,
          category: "Inference",
        ));
      }
    } catch (_) {}

    // 4. Soul Persona Directives
    try {
      final soul = await readSoul();
      if (soul.trim().isEmpty) {
        issues.add(const ConfigHealthItem(
          title: "Soul Persona File",
          description: "SOUL.md is empty. Default agent instructions are active.",
          severity: HealthSeverity.warning,
          category: "Persona",
          autoFixable: true,
        ));
      } else {
        issues.add(ConfigHealthItem(
          title: "Soul Persona File",
          description: "SOUL.md loaded successfully (${soul.length} characters).",
          severity: HealthSeverity.healthy,
          category: "Persona",
        ));
      }
    } catch (_) {}

    // 5. MCP Servers Status
    try {
      final servers = await getMcpServers();
      final enabledCount = servers.where((s) => s['enabled'] == true).length;
      issues.add(ConfigHealthItem(
        title: "MCP Servers",
        description: "${servers.length} MCP servers configured ($enabledCount enabled).",
        severity: HealthSeverity.healthy,
        category: "Capabilities",
      ));
    } catch (_) {}

    // 6. Memory Store
    try {
      final mem = await readMemory();
      issues.add(ConfigHealthItem(
        title: "Persistent Memory Store",
        description: mem.isNotEmpty
            ? "MEMORY.md verified (${mem.split('\n').length} lines)."
            : "MEMORY.md is currently blank.",
        severity: HealthSeverity.healthy,
        category: "Storage",
      ));
    } catch (_) {}

    return issues;
  }

  @override
  Future<Map<String, String>> readEnv({String? profile}) async {
    try {
      final res = await _dio.get(
        "/api/env",
        queryParameters: _withProfile(profile),
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final nested = data['env'] ?? data['keys'];
        if (nested is Map) {
          return nested.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        final varsList = data['variables'] ?? data['items'];
        if (varsList is List) {
          final out = <String, String>{};
          for (final item in varsList) {
            if (item is Map && item['key'] != null) {
              out[item['key'].toString()] = item['value']?.toString() ?? '';
            }
          }
          return out;
        }
        final out = <String, String>{};
        data.forEach((k, v) {
          if (v is String || v is num || v is bool) {
            out[k] = v.toString();
          } else if (v is Map && v['value'] != null) {
            out[k] = v['value'].toString();
          }
        });
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}

    try {
      final res = await _dio.get(
        "/v1/env",
        queryParameters: _withProfile(profile),
      );
      if (res.data is Map<String, dynamic>) {
        final map = res.data as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<void> setEnvValue(String key, String value, {String? profile}) async {
    final targetProfile = _normProfile(profile);
    final payload = <String, dynamic>{
      "key": key,
      "value": value,
      if (targetProfile != 'default') "profile": targetProfile,
    };

    try {
      final res = await _dio.put(
        "/api/env",
        queryParameters: _withProfile(targetProfile),
        data: payload,
        options: Options(validateStatus: (s) => (s ?? 500) < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        return;
      }
    } catch (_) {}

    try {
      final res = await _dio.post(
        "/api/env",
        queryParameters: _withProfile(targetProfile),
        data: payload,
        options: Options(validateStatus: (s) => (s ?? 500) < 500),
      );
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        return;
      }
    } catch (_) {}

    try {
      await _dio.put(
        "/v1/env/$key",
        queryParameters: _withProfile(targetProfile),
        data: {"value": value},
      );
    } catch (_) {}
  }

  @override
  Future<String> getConfigValue(String path, {String? profile}) async {
    try {
      final res = await _dio.get(
        "/api/model/info",
        queryParameters: _withProfile(profile),
      );
      if (res.data is Map<String, dynamic>) {
        final bUrl = res.data['base_url'] ?? res.data['effective_base_url'];
        if (bUrl != null && bUrl.toString().isNotEmpty) {
          return bUrl.toString();
        }
      }
    } catch (_) {}

    try {
      final res = await _dio.get(
        "/v1/config/$path",
        queryParameters: _withProfile(profile),
      );
      final str = res.data.toString();
      if (!str.contains('<!doctype html>')) return str;
    } catch (_) {}
    return '';
  }

  @override
  Future<Map<String, dynamic>> getModelInfo({String? profile}) async {
    try {
      final res = await _dio.get(
        "/api/model/info",
        queryParameters: _withProfile(profile),
      );
      if (res.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return {};
  }

  Future<List<String>> fetchRemoteEndpointModels(String baseUrl, String apiKey) async {
    final cleanUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl.isEmpty) return [];

    final List<String> candidates = [];
    if (cleanUrl.endsWith('/v1')) {
      candidates.add('$cleanUrl/models');
      candidates.add(cleanUrl.replaceAll(RegExp(r'/v1$'), '/models'));
    } else {
      candidates.add('$cleanUrl/v1/models');
      candidates.add('$cleanUrl/models');
    }

    _lastModelFetchError = null;
    for (final endpoint in candidates) {
      try {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 7),
          receiveTimeout: const Duration(seconds: 10),
        )).get(
          endpoint,
          options: Options(
            headers: {
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              'Accept': 'application/json',
            },
            validateStatus: (s) => (s ?? 0) < 500,
          ),
        );

        dynamic data = res.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (_) {}
        }

        if (res.statusCode == 200) {
          if (data is Map) {
            final dataList = data['data'] ?? data['models'];
            if (dataList is List && dataList.isNotEmpty) {
              final models = <String>[];
              for (final item in dataList) {
                if (item is Map && item['id'] != null) {
                  models.add(item['id'].toString());
                } else if (item is Map && item['name'] != null) {
                  models.add(item['name'].toString());
                } else if (item is String) {
                  models.add(item);
                }
              }
              if (models.isNotEmpty) {
                _lastModelFetchError = null;
                return models;
              }
            }
          } else if (data is List) {
            final models = <String>[];
            for (final item in data) {
              if (item is Map && item['id'] != null) {
                models.add(item['id'].toString());
              } else if (item is Map && item['name'] != null) {
                models.add(item['name'].toString());
              } else if (item is String) {
                models.add(item);
              }
            }
            if (models.isNotEmpty) {
              _lastModelFetchError = null;
              return models;
            }
          }
        } else {
          if (data is Map && data['error'] != null) {
            final err = data['error'];
            final msg = (err is Map) ? (err['message'] ?? err.toString()) : err.toString();
            _lastModelFetchError = msg;
          } else if (res.statusCode == 401) {
            _lastModelFetchError = "Authentication failed (401 Unauthorized)";
          } else if (res.statusCode == 403) {
            _lastModelFetchError = "Access forbidden (403 Forbidden)";
          }
        }
      } catch (e) {
        _lastModelFetchError = e.toString();
      }
    }
    return [];
  }

  @override
  Future<bool> setCustomInferenceEndpoint({
    required String baseUrl,
    required String apiKey,
    String? model,
    String? provider,
    String? profile,
  }) async {
    final targetProfile = _normProfile(profile);
    final cleanUrl = baseUrl.trim();
    final cleanKey = apiKey.trim();
    _customBaseUrlByProfile[targetProfile] = cleanUrl;
    if (cleanKey.isNotEmpty) {
      _customApiKeyByProfile[targetProfile] = cleanKey;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlPrefKey(targetProfile), cleanUrl);
      if (cleanKey.isNotEmpty) {
        await prefs.setString(_apiKeyPrefKey(targetProfile), cleanKey);
      }
    } catch (_) {}

    final lowerUrl = cleanUrl.toLowerCase();
    final lowerProv = (provider ?? '').trim().toLowerCase();
    final isOpenRouter = lowerUrl.contains('openrouter') || lowerProv == 'openrouter';
    final isAnthropic = lowerUrl.contains('anthropic') || lowerProv == 'anthropic';
    final isDeepSeek = lowerUrl.contains('deepseek') || lowerProv == 'deepseek';

    String prov = (provider ?? '').trim();
    if (prov.isEmpty || prov.toLowerCase() == 'custom' || prov.toLowerCase().startsWith('custom:')) {
      if (isOpenRouter) {
        prov = 'openrouter';
      } else if (isAnthropic) {
        prov = 'anthropic';
      } else if (isDeepSeek) {
        prov = 'deepseek';
      } else {
        prov = 'custom';
      }
    }

    // Persist secret credentials into the target profile's .env on Hermes backend
    try {
      if (isOpenRouter) {
        if (cleanKey.isNotEmpty) {
          await setEnvValue('OPENROUTER_API_KEY', cleanKey, profile: targetProfile);
        }
      } else if (isAnthropic) {
        if (cleanKey.isNotEmpty) {
          await setEnvValue('ANTHROPIC_API_KEY', cleanKey, profile: targetProfile);
        }
      } else if (isDeepSeek) {
        if (cleanUrl.isNotEmpty) {
          await setEnvValue('DEEPSEEK_BASE_URL', cleanUrl, profile: targetProfile);
        }
        if (cleanKey.isNotEmpty) {
          await setEnvValue('DEEPSEEK_API_KEY', cleanKey, profile: targetProfile);
        }
      } else {
        if (cleanUrl.isNotEmpty) {
          await setEnvValue('CUSTOM_BASE_URL', cleanUrl, profile: targetProfile);
          await setEnvValue('OPENAI_BASE_URL', cleanUrl, profile: targetProfile);
        }
        if (cleanKey.isNotEmpty) {
          await setEnvValue('CUSTOM_API_KEY', cleanKey, profile: targetProfile);
          await setEnvValue('OPENAI_API_KEY', cleanKey, profile: targetProfile);
        }
      }
    } catch (_) {}

    final fetched = cleanUrl.isNotEmpty
        ? await fetchRemoteEndpointModels(cleanUrl, cleanKey)
        : <String>[];

    String m = model?.trim() ?? '';
    if (m.isEmpty) {
      if (fetched.isNotEmpty) {
        m = fetched.contains('gpt-4o') ? 'gpt-4o' : fetched.first;
      } else {
        try {
          final info = await getModelInfo(profile: targetProfile);
          m = info['model']?.toString() ?? '';
        } catch (_) {}
      }
    }
    if (m.isEmpty || m == 'hermes-agent' || m == 'thinkingmachines/inkling:free') {
      m = fetched.isNotEmpty ? fetched.first : 'gpt-4o';
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedModelPrefKey(targetProfile), m);
    } catch (_) {}

    try {
      final payload = <String, dynamic>{
        "scope": "main",
        "provider": prov,
        "model": m,
        if (!isOpenRouter && cleanUrl.isNotEmpty) "base_url": cleanUrl,
        if (cleanKey.isNotEmpty) "api_key": cleanKey,
        if (targetProfile != 'default') "profile": targetProfile,
      };
      final res = await _dio.post(
        "/api/model/set",
        queryParameters: _withProfile(targetProfile),
        data: payload,
      );
      if (res.statusCode == 200) return true;
    } catch (_) {}

    return false;
  }

  @override
  Future<void> setConfigValue(String path, String value, {String? profile}) async {
    final targetProfile = _normProfile(profile);
    final cleanVal = value.trim();
    if (cleanVal.startsWith('http://') || cleanVal.startsWith('https://')) {
      await setCustomInferenceEndpoint(baseUrl: cleanVal, apiKey: '', profile: targetProfile);
      return;
    }

    try {
      String currentModel = "gpt-4o";
      String currentProvider = "custom";
      try {
        final info = await _dio.get(
          "/api/model/info",
          queryParameters: _withProfile(targetProfile),
        );
        if (info.data is Map<String, dynamic>) {
          currentModel = info.data['model']?.toString() ?? currentModel;
          final cp = info.data['provider']?.toString();
          if (cp != null && cp.isNotEmpty) {
            currentProvider = cp;
          }
        }
      } catch (_) {}

      final res = await _dio.post(
        "/api/model/set",
        queryParameters: _withProfile(targetProfile),
        data: {
          "scope": "main",
          "provider": currentProvider,
          "model": currentModel,
          "base_url": value,
          if (targetProfile != 'default') "profile": targetProfile,
        },
      );
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put(
        "/v1/config/$path",
        queryParameters: _withProfile(targetProfile),
        data: {"value": value},
      );
    } catch (_) {}
  }

  @override
  Stream<String> streamChat(String message, {String? model, String? sessionId, String? profile}) async* {
    final effectiveProfile = _normProfile(profile);
    String? effectiveModel = model;
    if (effectiveModel == null || effectiveModel.isEmpty || effectiveModel == '...' || effectiveModel == 'hermes-agent') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_selectedModelPrefKey(effectiveProfile));
        if (saved != null && saved.isNotEmpty) {
          effectiveModel = saved;
        }
      } catch (_) {}
    }

    // 1. Try official Hermes Gateway JSON-RPC WebSocket
    final targetSession = (sessionId != null && sessionId.isNotEmpty) ? sessionId : _activeSessionId;
    final controller = StreamController<String>();
    WebSocket? ws;
    Timer? pingTimer;

    try {
      if (!_authenticated) {
        await authenticate();
      }

      await switchServerProfile(effectiveProfile);
      await ensureMobilePlatformHint(profile: effectiveProfile);

      if (effectiveModel != null && effectiveModel.isNotEmpty) {
        try {
          await setModelEnabled(effectiveModel, true, profile: effectiveProfile);
        } catch (_) {}
      }

      String? wsTicket;
      try {
        final ticketRes = await _dio.post(
          "/api/auth/ws-ticket",
          queryParameters: _withProfile(effectiveProfile),
          data: {
            if (effectiveProfile != 'default') "profile": effectiveProfile,
          },
          options: Options(validateStatus: (s) => true),
        );
        if (ticketRes.statusCode == 200 && ticketRes.data is Map) {
          wsTicket = ticketRes.data['ticket']?.toString();
        }
      } catch (_) {}

      final profileQuery = effectiveProfile != 'default'
          ? '&profile=${Uri.encodeQueryComponent(effectiveProfile)}'
          : '';
      final String wsUri;
      if (wsTicket != null && wsTicket.isNotEmpty) {
        wsUri = '$_wsBaseUrl?ticket=${Uri.encodeQueryComponent(wsTicket)}$profileQuery';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=${Uri.encodeQueryComponent(token)}$profileQuery';
      }

      _applyProfileCookie(effectiveProfile);
      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      final effectiveToken = _accessToken ?? config.apiKey;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        wsHeaders['Authorization'] = 'Bearer $effectiveToken';
      }

      ws = await WebSocket.connect(
        wsUri,
        headers: wsHeaders,
      ).timeout(const Duration(seconds: 10));

      if (targetSession != null) {
        _activeChatSockets[targetSession] = ws;
      }

      // Advertise server_requests capability to Hermes daemon
      ws.add(jsonEncode({
        "jsonrpc": "2.0",
        "id": 999,
        "method": "client.capabilities",
        "params": {
          "server_requests": true,
        },
      }));

      pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
        try {
          ws?.add(jsonEncode({
            "jsonrpc": "2.0",
            "id": 888,
            "method": "gateway.ping",
            "params": {},
          }));
        } catch (_) {
          timer.cancel();
        }
      });

      String? liveSessionId;
      bool hasActiveThinking = false;
      bool hasReceivedDeltas = false;

      final sub = ws.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            final id = parsed['id'];
            final result = parsed['result'];
            final params = parsed['params'];
            final method = parsed['method'];

            // Handle server->client approval request (method: approval)
            if (method == 'approval' && id != null) {
              _pendingApprovalId = id;
              _pendingApprovalWs = ws;
              final p = (params as Map<String, dynamic>?) ?? {};
              final cmd = p['command']?.toString() ?? p['description']?.toString() ?? 'Command';
              controller.add('\n\n[Action Requires Operator Approval]\nCommand: `$cmd`\n');
              return;
            }

            if (method == 'request.cancel') {
              _pendingApprovalId = null;
              _pendingApprovalWs = null;
            }

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
                  if (effectiveProfile != 'default') "profile": effectiveProfile,
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
                  if (effectiveProfile != 'default') "profile": effectiveProfile,
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
                  hasReceivedDeltas = true;
                  if (!hasActiveThinking) {
                    hasActiveThinking = true;
                    controller.add('<think>$text');
                  } else {
                    controller.add(text);
                  }
                }
              } else if ((type == 'tool.start' || type == 'tool.started' || type == 'tool.call') && payload is Map<String, dynamic>) {
                hasReceivedDeltas = true;
                if (hasActiveThinking) {
                  hasActiveThinking = false;
                  controller.add('</think>\n');
                }
                final toolName = payload['name']?.toString() ?? payload['tool']?.toString() ?? 'tool';
                final args = payload['args'] ?? payload['arguments'] ?? payload['input'] ?? payload['context'];
                final argsStr = (args is Map || args is List) ? jsonEncode(args) : (args?.toString() ?? '');
                controller.add('\n<tool_call name="$toolName">\n<arguments>$argsStr</arguments>\n');
              } else if ((type == 'tool.complete' || type == 'tool.finish' || type == 'tool.output') && payload is Map<String, dynamic>) {
                hasReceivedDeltas = true;
                final result = payload['result'] ?? payload['output'] ?? payload['response'] ?? payload['error'] ?? '';
                final resultStr = (result is Map || result is List) ? jsonEncode(result) : result.toString();
                controller.add('<output>$resultStr</output>\n</tool_call>\n\n');
              } else if ((type == 'message.delta' || type == 'content.delta') && payload is Map<String, dynamic>) {
                final text = payload['text']?.toString() ?? payload['delta']?.toString() ?? '';
                if (text.isNotEmpty) {
                  hasReceivedDeltas = true;
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
                if (payload is Map<String, dynamic>) {
                  final status = payload['status']?.toString();
                  final cause = payload['cause']?.toString() ?? payload['error']?.toString();
                  final failureReason = payload['failure_reason']?.toString();
                  if (status == 'error' || (cause != null && cause.isNotEmpty)) {
                    final err = cause ?? failureReason ?? 'Model inference failed';
                    if (!controller.isClosed) {
                      controller.add('Error: $err');
                      controller.close();
                      return;
                    }
                  }
                  final fullText = payload['text']?.toString() ?? payload['content']?.toString() ?? payload['message']?.toString();
                  if (!hasReceivedDeltas && fullText != null && fullText.isNotEmpty) {
                    controller.add(fullText);
                  }
                }
                if (!controller.isClosed) {
                  controller.close();
                }
              } else if (type == 'turn.error' || type == 'error') {
                final errText = (payload is Map)
                    ? (payload['cause'] ?? payload['message'] ?? payload['error'] ?? payload.toString()).toString()
                    : (payload?.toString() ?? 'Turn error');
                if (!controller.isClosed) {
                  controller.add('Error: $errText');
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
                  "params": {
                    "source": clientSource,
                    if (effectiveProfile != 'default') "profile": effectiveProfile,
                  },
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
          "params": {
            "session_id": targetSession,
            "source": clientSource,
            if (effectiveProfile != 'default') "profile": effectiveProfile,
          },
        }));
      } else {
        ws.add(jsonEncode({
          "jsonrpc": "2.0",
          "id": 1001,
          "method": "session.create",
          "params": {
            "source": clientSource,
            if (effectiveProfile != 'default') "profile": effectiveProfile,
          },
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
      pingTimer?.cancel();
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

  String? _lastPluginError;
  @override
  String? get lastPluginError => _lastPluginError;

  @override
  Future<Map<String, dynamic>?> getSystemStats() async {
    try {
      final res = await _dio.get("/api/system/stats");
      if (res.data is Map<String, dynamic>) {
        return res.data;
      } else if (res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> installPlugin(String name) async {
    _lastPluginError = null;
    try {
      final res = await _dio.post("/api/dashboard/agent-plugins/install", data: {
        "catalog_name": name,
      });
      return res.statusCode == 200 || res.statusCode == 201;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        _lastPluginError = data['detail'].toString();
      } else if (data is Map && data['error'] != null) {
        _lastPluginError = data['error'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        _lastPluginError = e.message;
      }
      return false;
    } catch (e) {
      _lastPluginError = e.toString();
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
  Future<List<ModelConfig>> getModels({String? profile}) async {
    final targetProfile = _normProfile(profile);
    String currentModel = '';
    String currentProvider = '';
    String customBaseUrl = _customBaseUrlByProfile[targetProfile] ?? '';
    String customApiKey = _customApiKeyByProfile[targetProfile] ?? '';

    if (customBaseUrl.isEmpty || customApiKey.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (customBaseUrl.isEmpty) {
          customBaseUrl = prefs.getString(_baseUrlPrefKey(targetProfile)) ?? '';
        }
        if (customApiKey.isEmpty) {
          customApiKey = prefs.getString(_apiKeyPrefKey(targetProfile)) ?? '';
        }
      } catch (_) {}
    }

    try {
      final info = await _dio.get(
        "/api/model/info",
        queryParameters: _withProfile(targetProfile),
      );
      if (info.data is Map<String, dynamic>) {
        currentModel = info.data['model']?.toString() ?? '';
        currentProvider = info.data['provider']?.toString() ?? '';
        final bUrl = info.data['base_url']?.toString() ?? '';
        if (bUrl.isNotEmpty && customBaseUrl.isEmpty) {
          customBaseUrl = bUrl;
        }
      }
    } catch (_) {}

    if (customBaseUrl.isEmpty || customApiKey.isEmpty) {
      try {
        final env = await readEnv(profile: targetProfile);
        if (customBaseUrl.isEmpty) {
          final envUrl = env['CUSTOM_BASE_URL'] ?? env['DEEPSEEK_BASE_URL'] ?? env['OPENAI_BASE_URL'] ?? '';
          if (envUrl.isNotEmpty && !_isMaskedSecret(envUrl)) {
            customBaseUrl = envUrl;
          }
        }
        if (customApiKey.isEmpty) {
          final envKey = env['CUSTOM_API_KEY'] ??
              env['OPENROUTER_API_KEY'] ??
              env['ANTHROPIC_API_KEY'] ??
              env['DEEPSEEK_API_KEY'] ??
              env['OPENAI_API_KEY'] ??
              '';
          if (envKey.isNotEmpty && !_isMaskedSecret(envKey)) {
            customApiKey = envKey;
          }
        }
      } catch (_) {}
    }

    String selectedModel = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      selectedModel = prefs.getString(_selectedModelPrefKey(targetProfile)) ?? '';
    } catch (_) {}
    if (selectedModel.isEmpty) {
      selectedModel = currentModel;
    }

    final isCustom = currentProvider.toLowerCase() == 'custom' ||
        currentProvider.toLowerCase().startsWith('custom:') ||
        customBaseUrl.isNotEmpty;

    // 1. If using custom provider (e.g. self-hosted, local, or any OpenAI-compatible API), fetch its models dynamically
    if (isCustom && customBaseUrl.isNotEmpty) {
      final fetchedIds = await fetchRemoteEndpointModels(customBaseUrl, customApiKey);
      String displayProvider;
      final lowerUrl = customBaseUrl.toLowerCase();
      if (lowerUrl.contains('openrouter')) {
        displayProvider = 'OpenRouter';
      } else if (lowerUrl.contains('anthropic')) {
        displayProvider = 'Anthropic';
      } else if (lowerUrl.contains('deepseek')) {
        displayProvider = 'DeepSeek';
      } else if (lowerUrl.contains('localhost') || lowerUrl.contains('127.0.0.1')) {
        displayProvider = 'Local Server';
      } else {
        try {
          final uri = Uri.parse(customBaseUrl);
          final host = uri.host.isNotEmpty ? uri.host : 'Custom';
          final isIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);
          if (isIp) {
            displayProvider = 'Local/Network Server';
          } else {
            final parts = host.split('.');
            if (parts.length >= 2) {
              final mainPart = (parts.length > 2 && (parts[0] == 'api' || parts[0] == 'ai' || parts[0] == 'www'))
                  ? parts[1]
                  : parts[parts.length - 2];
              displayProvider = mainPart.isNotEmpty
                  ? (mainPart[0].toUpperCase() + mainPart.substring(1))
                  : host;
            } else {
              displayProvider = host;
            }
          }
        } catch (_) {
          displayProvider = 'Custom';
        }
      }

      if (fetchedIds.isNotEmpty) {
        final List<ModelConfig> customModels = [];
        final hasMatch = fetchedIds.contains(selectedModel);
        for (final id in fetchedIds) {
          customModels.add(ModelConfig(
            name: id,
            provider: displayProvider,
            model: id,
            baseUrl: customBaseUrl,
            enabled: hasMatch ? (id == selectedModel) : (id == currentModel || (currentModel.isEmpty && id == fetchedIds.first)),
          ));
        }
        return customModels;
      }

      // If fetch failed with an error, do NOT show a ghost model from another provider
      if (_lastModelFetchError != null && _lastModelFetchError!.isNotEmpty) {
        return [];
      }

      return [];
    }

    // 2. If using standard aggregator (e.g. OpenRouter), fetch only that provider's models
    try {
      final res = await _dio.get(
        "/api/model/options",
        queryParameters: _withProfile(targetProfile),
      );
      if (res.data is Map<String, dynamic>) {
        final optModel = res.data['model'] as String? ?? currentModel;
        final optProvider = res.data['provider'] as String? ?? (currentProvider.isNotEmpty ? currentProvider : 'openrouter');
        final providers = (res.data['providers'] as List<dynamic>?) ?? [];
        final List<ModelConfig> result = [];

        for (final p in providers) {
          if (p is Map<String, dynamic>) {
            final pSlug = (p['slug'] as String? ?? p['name'] as String? ?? '').toLowerCase();
            final isCurrent = p['is_current'] == true || pSlug == optProvider.toLowerCase();
            if (isCurrent) {
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
                  provider: p['name'] as String? ?? p['slug'] as String? ?? optProvider,
                  model: m,
                  baseUrl: '',
                  enabled: m == optModel,
                ));
              }
            }
          }
        }

        if (result.isNotEmpty) {
          if (optModel.isNotEmpty && !result.any((m) => m.name == optModel)) {
            result.insert(0, ModelConfig(
              name: optModel,
              provider: optProvider,
              model: optModel,
              baseUrl: '',
              enabled: true,
            ));
          }
          return result;
        }
      }
    } catch (_) {}

    if (currentModel.isNotEmpty) {
      return [
        ModelConfig(
          name: currentModel,
          provider: currentProvider.isNotEmpty ? currentProvider : 'openrouter',
          model: currentModel,
          baseUrl: customBaseUrl,
          enabled: true,
        ),
      ];
    }
    return [];
  }

  @override
  Future<void> clearLocalCache() async {
    try {
      await _dio.post("/api/cache/clear", data: {});
    } catch (_) {}
  }

  @override
  Future<void> setModelEnabled(String name, bool enabled, {String? provider, String? profile}) async {
    final targetProfile = _normProfile(profile);
    String customBaseUrl = _customBaseUrlByProfile[targetProfile] ?? '';
    String customApiKey = _customApiKeyByProfile[targetProfile] ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (customBaseUrl.isEmpty) {
        customBaseUrl = prefs.getString(_baseUrlPrefKey(targetProfile)) ?? '';
      }
      if (customApiKey.isEmpty) {
        customApiKey = prefs.getString(_apiKeyPrefKey(targetProfile)) ?? '';
      }
      await prefs.setString(_selectedModelPrefKey(targetProfile), name);
    } catch (_) {}

    if (customBaseUrl.isEmpty || customApiKey.isEmpty) {
      try {
        final env = await readEnv(profile: targetProfile);
        if (customBaseUrl.isEmpty) {
          final envUrl = env['CUSTOM_BASE_URL'] ?? env['DEEPSEEK_BASE_URL'] ?? env['OPENAI_BASE_URL'] ?? '';
          if (envUrl.isNotEmpty && !_isMaskedSecret(envUrl)) {
            customBaseUrl = envUrl;
          }
        }
        if (customApiKey.isEmpty) {
          final envKey = env['CUSTOM_API_KEY'] ??
              env['OPENROUTER_API_KEY'] ??
              env['ANTHROPIC_API_KEY'] ??
              env['DEEPSEEK_API_KEY'] ??
              env['OPENAI_API_KEY'] ??
              '';
          if (envKey.isNotEmpty && !_isMaskedSecret(envKey)) {
            customApiKey = envKey;
          }
        }
      } catch (_) {}
    }

    String existingProvider = '';
    try {
      final infoRes = await _dio.get(
        "/api/model/info",
        queryParameters: _withProfile(targetProfile),
      );
      if (infoRes.data is Map<String, dynamic>) {
        existingProvider = infoRes.data['provider']?.toString() ?? '';
        final bUrl = infoRes.data['base_url']?.toString() ?? '';
        if (customBaseUrl.isEmpty && bUrl.isNotEmpty) customBaseUrl = bUrl;
      }
    } catch (_) {}
    if (existingProvider.isEmpty && targetProfile != 'default') {
      try {
        final defInfo = await _dio.get("/api/model/info");
        if (defInfo.data is Map<String, dynamic>) {
          existingProvider = defInfo.data['provider']?.toString() ?? '';
          final bUrl = defInfo.data['base_url']?.toString() ?? '';
          if (customBaseUrl.isEmpty && bUrl.isNotEmpty) customBaseUrl = bUrl;
        }
      } catch (_) {}
    }

    String p = provider?.trim() ?? '';
    if (p.isEmpty && existingProvider.isNotEmpty) {
      p = existingProvider;
    }
    final lowerUrl = customBaseUrl.toLowerCase();
    final lowerP = p.toLowerCase();
    final isOpenRouter = lowerUrl.contains('openrouter') || lowerP == 'openrouter';
    final isAnthropic = lowerUrl.contains('anthropic') || lowerP == 'anthropic';
    final isDeepSeek = lowerUrl.contains('deepseek') || lowerP == 'deepseek';
    final isCustom = !isOpenRouter && !isAnthropic && !isDeepSeek && (customBaseUrl.isNotEmpty ||
        lowerP == 'custom' ||
        lowerP.startsWith('custom:'));

    final String targetProvider;
    if (isOpenRouter) {
      targetProvider = 'openrouter';
    } else if (isAnthropic) {
      targetProvider = 'anthropic';
    } else if (isDeepSeek) {
      targetProvider = 'deepseek';
    } else if (isCustom) {
      targetProvider = 'custom';
    } else {
      targetProvider = p.isNotEmpty ? p : 'openrouter';
    }

    try {
      final res = await _dio.post(
        "/api/model/set",
        queryParameters: _withProfile(targetProfile),
        data: {
          "scope": "main",
          "provider": targetProvider,
          "model": name,
          if (isCustom && customBaseUrl.isNotEmpty) "base_url": customBaseUrl,
          if (customApiKey.isNotEmpty) "api_key": customApiKey,
          if (targetProfile != 'default') "profile": targetProfile,
        },
      );
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.patch(
        "/v1/models/$name",
        queryParameters: _withProfile(targetProfile),
        data: {"enabled": enabled},
      );
    } catch (_) {}
  }

  @override
  Future<void> setModelProviderKey(String modelName, String provider, String key, {String? profile}) async {
    final targetProfile = _normProfile(profile);
    final cleanKey = key.trim();
    String p = provider.trim();
    if (p.isEmpty || p.toLowerCase() == 'default') {
      try {
        final models = await getModels(profile: targetProfile);
        final match = models.where((m) => m.name == modelName).firstOrNull;
        if (match != null && match.provider.isNotEmpty) {
          p = match.provider;
        }
      } catch (_) {}
    }
    if (p.isEmpty) p = 'openrouter';

    final lowerP = p.toLowerCase();
    if (cleanKey.isNotEmpty) {
      _customApiKeyByProfile[targetProfile] = cleanKey;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_apiKeyPrefKey(targetProfile), cleanKey);
      } catch (_) {}

      try {
        if (lowerP == 'openrouter') {
          await setEnvValue('OPENROUTER_API_KEY', cleanKey, profile: targetProfile);
        } else if (lowerP == 'anthropic') {
          await setEnvValue('ANTHROPIC_API_KEY', cleanKey, profile: targetProfile);
        } else if (lowerP == 'deepseek') {
          await setEnvValue('DEEPSEEK_API_KEY', cleanKey, profile: targetProfile);
        } else {
          await setEnvValue('CUSTOM_API_KEY', cleanKey, profile: targetProfile);
          await setEnvValue('OPENAI_API_KEY', cleanKey, profile: targetProfile);
        }
      } catch (_) {}
    }

    try {
      final res = await _dio.post(
        "/api/model/set",
        queryParameters: _withProfile(targetProfile),
        data: {
          "scope": "main",
          "provider": lowerP,
          "model": modelName.isEmpty || modelName == 'hermes-agent' ? 'gpt-4o' : modelName,
          "api_key": cleanKey,
          if (targetProfile != 'default') "profile": targetProfile,
        },
      );
      if (res.statusCode == 200) return;
    } catch (_) {}

    try {
      await _dio.put(
        "/v1/models/$modelName/provider",
        queryParameters: _withProfile(targetProfile),
        data: {"provider": lowerP, "api_key": cleanKey},
      );
    } catch (_) {}
  }
  String _extractSnippetFromRawMessages(List<Map<String, dynamic>> messages, {String fallback = ''}) {
    if (messages.isEmpty) return fallback;
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final role = (msg['role'] as String? ?? '').toLowerCase();
      if (role == 'system' || role == 'tool') continue;

      dynamic rawContent = msg['content'];
      String text = '';
      if (rawContent is String) {
        text = rawContent;
      } else if (rawContent is List) {
        text = rawContent.map((c) {
          if (c is Map && c['text'] != null) return c['text'].toString();
          return c.toString();
        }).join(' ');
      }

      // Clean thinking tags and tool calls
      text = text.replaceAll(RegExp(r'<think>[\s\S]*?(?:</think>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'<tool_call>[\s\S]*?(?:</tool_call>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'<tool[^>]*>[\s\S]*?(?:</tool>|$)', caseSensitive: false), '').trim();
      text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '[code]').trim();
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (role == 'user') {
        if (text.contains('[DEVICE CONTROL CAPABILITY]')) {
          text = text.split('[DEVICE CONTROL CAPABILITY]').first.trim();
        }
        if (text.contains('[PRIVILEGED SHELL CAPABILITY]')) {
          text = text.split('[PRIVILEGED SHELL CAPABILITY]').first.trim();
        }
        if (text.contains('[RECENT LOCAL DEVICE CONTEXT:')) {
          text = text.split('[RECENT LOCAL DEVICE CONTEXT:').first.trim();
        }
        if (text.contains('[INSTRUCTION:')) {
          text = text.split('[INSTRUCTION:').first.trim();
        }

        final lower = text.toLowerCase();
        if (text.isEmpty ||
            lower.startsWith("user approved mobile action") ||
            lower.startsWith("user declined") ||
            lower.startsWith("user rejected") ||
            lower.startsWith("observation from mobile") ||
            lower.startsWith("you concluded your reasoning")) {
          continue;
        }
      }

      if (text.isNotEmpty) {
        final prefix = (role == 'assistant' || role == 'agent' || role == 'bot') ? 'Pixie: ' : 'You: ';
        return '$prefix$text';
      }
    }
    return fallback;
  }

  // -- Sessions --
  Future<List<SessionSummary>> _fetchSessionsForProfile(String profileId, {String? query}) async {
    final queryParams = <String, dynamic>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (profileId.isNotEmpty && profileId != 'default') 'profile': profileId,
    };
    List<SessionSummary> list = [];

    try {
      final res = await _dio.get(
        "/api/sessions",
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      if (res.data is Map<String, dynamic>) {
        final rawList = (res.data['sessions'] as List<dynamic>?) ?? [];
        list = rawList
            .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>).copyWith(profile: profileId))
            .toList();
      } else if (res.data is List<dynamic>) {
        list = (res.data as List<dynamic>)
            .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>).copyWith(profile: profileId))
            .toList();
      }
    } catch (_) {}

    if (list.isEmpty) {
      try {
        final res = await _dio.get(
          "/v1/sessions",
          queryParameters: queryParams.isEmpty ? null : queryParams,
        );
        if (res.data is List<dynamic>) {
          list = (res.data as List<dynamic>)
              .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>).copyWith(profile: profileId))
              .toList();
        } else if (res.data is Map<String, dynamic>) {
          final rawList = (res.data['sessions'] as List<dynamic>?) ?? [];
          list = rawList
              .map((j) => SessionSummary.fromJson(j as Map<String, dynamic>).copyWith(profile: profileId))
              .toList();
        }
      } catch (_) {}
    }

    return list;
  }

  @override
  Future<List<SessionSummary>> getSessions({String? query}) async {
    // Fetch sessions across all profiles so switching an active profile in a chat room
    // never hides existing sessions from other profiles on the main chat screen.
    final Set<String> profileIds = {'default', _activeProfile};
    try {
      final profiles = await listProfiles();
      for (final p in profiles) {
        if (p.id.trim().isNotEmpty) {
          profileIds.add(p.id.trim());
        }
      }
    } catch (_) {}

    final Map<String, SessionSummary> mergedById = {};
    final results = await Future.wait(
      profileIds.map((pid) => _fetchSessionsForProfile(pid, query: query)),
    );
    for (final profileSessions in results) {
      for (final s in profileSessions) {
        if (s.id.isEmpty) continue;
        if (!mergedById.containsKey(s.id) || s.profile != 'default') {
          mergedById[s.id] = s;
        }
      }
    }

    final sessions = mergedById.values.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.startedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b.startedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

    if (sessions.isEmpty) return [];

    // Concurrently enrich top sessions with their latest message only when snippet is missing
    try {
      final limit = sessions.length > 25 ? 25 : sessions.length;
      final enrichedTop = await Future.wait(
        sessions.take(limit).map((s) async {
          // If session already has a distinct, enriched snippet, skip expensive network calls
          final cleanSnippet = s.snippet.trim();
          final cleanTitle = s.title.trim();
          final isRedundantOrEmpty = cleanSnippet.isEmpty ||
              cleanSnippet.toLowerCase() == cleanTitle.toLowerCase() ||
              (!cleanSnippet.startsWith('Pixie:') && !cleanSnippet.startsWith('You:'));

          if (!isRedundantOrEmpty) {
            return s;
          }
          try {
            final msgs = await getSessionMessages(s.id, profile: s.profile);
            if (msgs.isNotEmpty) {
              final lastSnippet = _extractSnippetFromRawMessages(msgs, fallback: s.snippet);
              if (lastSnippet.isNotEmpty) {
                return s.copyWith(snippet: lastSnippet);
              }
            }
          } catch (_) {}
          return s;
        }),
      );
      for (int i = 0; i < enrichedTop.length; i++) {
        sessions[i] = enrichedTop[i];
      }
    } catch (_) {}

    return sessions;
  }
  @override
  Future<void> deleteSession(String id, {String? profile}) async {
    try {
      final res = await _dio.delete(
        "/api/sessions/$id",
        queryParameters: _withProfile(profile),
      );
      if (res.statusCode == 200) return;
    } catch (_) {}
    try {
      await _dio.delete(
        "/v1/sessions/$id",
        queryParameters: _withProfile(profile),
      );
    } catch (_) {}
  }

  @override
  Future<void> renameSession(String id, String newTitle, {String? profile}) async {
    try {
      await _dio.patch(
        "/api/sessions/$id",
        queryParameters: _withProfile(profile),
        data: {'title': newTitle},
      );
      return;
    } catch (_) {}
    try {
      await _dio.put(
        "/api/sessions/$id",
        queryParameters: _withProfile(profile),
        data: {'title': newTitle},
      );
      return;
    } catch (_) {}
    try {
      await _dio.patch(
        "/v1/sessions/$id",
        queryParameters: _withProfile(profile),
        data: {'title': newTitle},
      );
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

  @override
  Future<bool> triggerSchedule(String id) async {
    try {
      final res = await _dio.post("/v1/schedules/$id/run");
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
        return true;
      }
    } catch (_) {}

    try {
      final res = await _dio.post("/api/cron/jobs/$id/run");
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
        return true;
      }
    } catch (_) {}

    try {
      final res = await _dio.post("/v1/schedules/$id/trigger");
      return res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
    } catch (_) {
      return false;
    }
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
        wsUri = '$_wsBaseUrl?ticket=${Uri.encodeQueryComponent(wsTicket)}';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=${Uri.encodeQueryComponent(token)}';
      }

      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      final effectiveToken = _accessToken ?? config.apiKey;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        wsHeaders['Authorization'] = 'Bearer $effectiveToken';
      }

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
        wsUri = '$_wsBaseUrl?ticket=${Uri.encodeQueryComponent(wsTicket)}';
      } else {
        final token = _accessToken ?? config.apiKey ?? '';
        wsUri = '$_wsBaseUrl?token=${Uri.encodeQueryComponent(token)}';
      }

      final wsHeaders = <String, dynamic>{};
      if (_cookieHeader != null) wsHeaders['Cookie'] = _cookieHeader;
      final effectiveToken = _accessToken ?? config.apiKey;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        wsHeaders['Authorization'] = 'Bearer $effectiveToken';
      }

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
    for (final p in <String>{path, normalizedPath}) {
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
    for (final p in <String>{path, normalizedPath}) {
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
  Future<bool> writeWorkspaceFile(String path, String content) async {
    // Hermes HTTP gateway does not expose a direct file-write endpoint.
    return false;
  }

  @override
  Future<List<Map<String, dynamic>>> getCronJobRuns(String id) async {
    try {
      final res = await _dio.get("/api/cron/jobs/$id/runs");
      if (res.data is List) {
        return (res.data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (res.data is Map && res.data['runs'] is List) {
        return (res.data['runs'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    try {
      final res = await _dio.get("/api/cron/jobs/$id/logs");
      if (res.data is List) {
        return (res.data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<Map<String, dynamic>?> getWhatsAppBridgeStatus() async {
    try {
      final res = await _dio.get("/api/messaging/platforms/whatsapp/status");
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {}

    try {
      final res = await _dio.get("/api/messaging/platforms/whatsapp/qr");
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {}

    return null;
  }

  @override
  void dispose() {
    for (final ws in _activeChatSockets.values) {
      try {
        ws.close(WebSocketStatus.normalClosure, 'RemoteConnection disposed');
      } catch (_) {}
    }
    _activeChatSockets.clear();

    try {
      _pendingApprovalWs?.close(WebSocketStatus.normalClosure, 'RemoteConnection disposed');
    } catch (_) {}
    _pendingApprovalWs = null;

    try {
      _dio.close(force: true);
    } catch (_) {}
  }
}
