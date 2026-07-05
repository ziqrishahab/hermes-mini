import "dart:async";
import "dart:convert";
import "package:dio/dio.dart";
import "../models/connection_config.dart";
import "../models/sse_event.dart";
import "hermes_connection.dart";
class RemoteConnection extends HermesConnection {
  final ConnectionConfig config;
  late final Dio _dio;
  RemoteConnection(this.config) {
    _dio = Dio(BaseOptions(
      baseUrl: config.apiUrl!.replaceAll(RegExp(r"/$"), ""),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        if (config.apiKey?.isNotEmpty ?? false)
          "Authorization": "Bearer ${config.apiKey}",
        "Accept": "text/event-stream",
      },
    ));
  }
  @override
  Future<bool> testConnection() async {
    try {
      final res = await _dio.get("/health");
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  @override
  Future<String> health() async {
    final res = await _dio.get("/health");
    return res.data.toString();
  }

  @override
  Future<String> getSkillContent(String skillName) async {
    final res = await _dio.get("/v1/skills/$skillName/content");
    return res.data.toString();
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final res = await _dio.get("/v1/sessions/$sessionId/messages");
    return (res.data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, bool>> getPlatformEnabled() async {
    final res = await _dio.get("/v1/platforms");
    final map = res.data as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as bool));
  }

  @override
  Future<void> setPlatformEnabled(String platform, bool enabled) async {
    await _dio.patch("/v1/platforms/$platform", data: {"enabled": enabled});
  }

  @override
  Future<String> readMemory() async {
    final res = await _dio.get("/v1/memory");
    return res.data.toString();
  }

  @override
  Future<String> readUserProfile() async {
    final res = await _dio.get("/v1/user/profile");
    return res.data.toString();
  }

  @override
  Future<void> writeMemory(String content) async {
    await _dio.put("/v1/memory", data: {"content": content});
  }

  @override
  Future<void> writeUserProfile(String content) async {
    await _dio.put("/v1/user/profile", data: {"content": content});
  }

  @override
  Future<Map<String, String>> readEnv() async {
    final res = await _dio.get("/v1/env");
    final map = res.data as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  }

  @override
  Future<void> setEnvValue(String key, String value) async {
    await _dio.put("/v1/env/$key", data: {"value": value});
  }

  @override
  Future<String> getConfigValue(String path) async {
    final res = await _dio.get("/v1/config/$path");
    return res.data.toString();
  }

  @override
  Future<void> setConfigValue(String path, String value) async {
    await _dio.put("/v1/config/$path", data: {"value": value});
  }

  @override
  Stream<String> streamChat(String message) async* {
    final response = await _dio.post<ResponseBody>(
      "/v1/chat/completions",
      data: {
        "model": "hermes-agent",
        "messages": [
          {"role": "user", "content": message},
        ],
        "stream": true,
      },
      options: Options(responseType: ResponseType.stream),
    );
    final stream = response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in stream) {
      final event = SseEvent.fromLine(line);
      if (event.type == "done") break;
      if (event.type == "error") throw Exception(event.content ?? "Stream error");
      if (event.type == "delta" && event.content != null) yield event.content!;
    }
  }
  // -- Skills --
  @override
  Future<List<SkillInfo>> getSkills() async {
    final res = await _dio.get("/v1/skills");
    final list = res.data as List<dynamic>;
    return list.map((j) => SkillInfo.fromJson(j as Map<String, dynamic>)).toList();
  }
  @override
  Future<void> setSkillEnabled(String name, bool enabled) async {
    await _dio.patch("/v1/skills/$name", data: {"enabled": enabled});
  }
  // -- Toolsets --
  @override
  Future<List<ToolsetInfo>> getToolsets() async {
    final res = await _dio.get("/v1/toolsets");
    final list = res.data as List<dynamic>;
    return list.map((j) => ToolsetInfo.fromJson(j as Map<String, dynamic>)).toList();
  }
  @override
  Future<void> setToolsetEnabled(String name, bool enabled) async {
    await _dio.patch("/v1/toolsets/$name", data: {"enabled": enabled});
  }
  // -- Models --
  @override
  Future<List<ModelConfig>> getModels() async {
    final res = await _dio.get("/v1/models");
    final list = res.data as List<dynamic>;
    return list.map((j) => ModelConfig.fromJson(j as Map<String, dynamic>)).toList();
  }
  @override
  Future<void> setModelEnabled(String name, bool enabled) async {
    await _dio.patch("/v1/models/$name", data: {"enabled": enabled});
  }
  @override
  Future<void> setModelProviderKey(String modelName, String provider, String key) async {
    await _dio.put("/v1/models/$modelName/provider", data: {"provider": provider, "api_key": key});
  }
  // -- Sessions --
  @override
  Future<List<SessionSummary>> getSessions({String? query}) async {
    final qp = query != null ? "?q=$query" : "";
    final res = await _dio.get("/v1/sessions$qp");
    final list = res.data as List<dynamic>;
    return list.map((j) => SessionSummary.fromJson(j as Map<String, dynamic>)).toList();
  }
  @override
  Future<void> deleteSession(String id) async {
    await _dio.delete("/v1/sessions/$id");
  }
  // -- Schedules --
  @override
  Future<List<Map<String, dynamic>>> getSchedules() async {
    final res = await _dio.get("/v1/schedules");
    return (res.data as List<dynamic>).cast<Map<String, dynamic>>();
  }
  @override
  Future<void> createSchedule(Map<String, dynamic> schedule) async {
    await _dio.post("/v1/schedules", data: schedule);
  }
  @override
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule) async {
    await _dio.put("/v1/schedules/$id", data: schedule);
  }
  @override
  Future<void> deleteSchedule(String id) async {
    await _dio.delete("/v1/schedules/$id");
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
  @override
  void dispose() {}
}
