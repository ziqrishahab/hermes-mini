import 'dart:async';
import 'remote_connection.dart';
import 'ssh_connection.dart';
import '../models/connection_config.dart';

// Data classes

class SkillInfo {
  final String name;
  final String category;
  final String description;
  final String path;
  final bool enabled;

  const SkillInfo({
    required this.name,
    required this.category,
    required this.description,
    required this.path,
    this.enabled = true,
  });

  factory SkillInfo.fromJson(Map<String, dynamic> json) {
    return SkillInfo(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      path: json['path'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'description': description,
        'path': path,
        'enabled': enabled,
      };
}

class ToolsetInfo {
  final String key;
  final String label;
  final String description;
  final bool enabled;

  const ToolsetInfo({
    required this.key,
    required this.label,
    required this.description,
    this.enabled = true,
  });

  factory ToolsetInfo.fromJson(Map<String, dynamic> json) {
    final k = json['key'] as String? ?? json['name'] as String? ?? '';
    final l = json['label'] as String? ?? json['name'] as String? ?? k;
    return ToolsetInfo(
      key: k,
      label: l,
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'description': description,
        'enabled': enabled,
      };
}

class SessionSummary {
  final String id;
  final String title;
  final String startedAt;
  final String source;
  final int messageCount;
  final String model;
  final String snippet;
  final int unreadCount;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.source,
    required this.messageCount,
    required this.model,
    this.snippet = '',
    this.unreadCount = 0,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    String startedAtStr = '';
    final rawStarted = json['startedAt'] ?? json['started_at'];
    if (rawStarted is num) {
      startedAtStr = DateTime.fromMillisecondsSinceEpoch((rawStarted * 1000).toInt()).toIso8601String();
    } else if (rawStarted != null) {
      startedAtStr = rawStarted.toString();
    }

    int unread = 0;
    if (json['unreadCount'] is int) {
      unread = json['unreadCount'] as int;
    } else if (json['unread'] == true) {
      unread = 1;
    }

    return SessionSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Session',
      startedAt: startedAtStr,
      source: json['source'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? json['message_count'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      snippet: json['snippet'] as String? ?? json['preview'] as String? ?? '',
      unreadCount: unread,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startedAt': startedAt,
        'source': source,
        'messageCount': messageCount,
        'model': model,
        'snippet': snippet,
        'unreadCount': unreadCount,
      };
}

class ModelConfig {
  final String name;
  final String provider;
  final String model;
  final String baseUrl;
  final bool enabled;
  final String? apiKeyHint;

  const ModelConfig({
    required this.name,
    required this.provider,
    required this.model,
    required this.baseUrl,
    this.enabled = true,
    this.apiKeyHint,
  });

  String get providerKey => provider;

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      name: json['name'] as String? ?? json['model'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      apiKeyHint: json['apiKeyHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'provider': provider,
        'model': model,
        'baseUrl': baseUrl,
        'enabled': enabled,
        'apiKeyHint': apiKeyHint,
      };
}

// Abstract connection interface

abstract class HermesConnection {
  Future<bool> testConnection();
  Future<String> health();
  String? get activeSessionId => null;
  set activeSessionId(String? id) {}

  Stream<String> streamChat(String message, {String? model, String? sessionId});
  Future<bool> stopGeneration({String? sessionId}) async => false;
  void dispose();

  Future<List<SkillInfo>> getSkills();
  Future<void> setSkillEnabled(String name, bool enabled);
  Future<String> getSkillContent(String skillName);

  Future<List<ToolsetInfo>> getToolsets();
  Future<void> setToolsetEnabled(String key, bool enabled);
  Future<List<Map<String, dynamic>>> getMcpServers() async => [];
  Future<List<Map<String, dynamic>>> getMcpCatalog() async => [];
  Future<bool> installMcpCatalogEntry(String name, Map<String, String> env) async => false;
  Future<bool> uninstallMcpServer(String name) async => false;
  Future<bool> setMcpServerEnabled(String name, bool enabled) async => false;
  Future<List<Map<String, dynamic>>> getPlugins() async => [];
  Future<Map<String, dynamic>?> getPluginApi(String pluginName, String path) async => null;
  Future<String> executeSlashCommand(String command, {String? sessionId}) async => '';

  Future<List<ModelConfig>> getModels();
  Future<void> setModelEnabled(String name, bool enabled);
  Future<void> setModelProviderKey(String modelName, String provider, String key);

  Future<String> getReasoningEffort() async => 'low';
  Future<bool> setReasoningEffort(String effort) async => false;
  Future<String?> getActiveWorkspaceCwd() async => null;
  Future<bool> setActiveWorkspaceCwd(String path) async => false;
  Future<List<Map<String, dynamic>>> getProjectsList() async => [];
  Future<List<Map<String, dynamic>>> listWorkspaceFiles({String? subpath}) async => [];
  Future<String?> readWorkspaceFile(String path) async => null;

  Future<List<SessionSummary>> getSessions({String? query});
  Future<void> deleteSession(String id);
  Future<void> renameSession(String id, String newTitle) async {}
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId);

  Future<List<Map<String, dynamic>>> getSchedules();
  Future<void> createSchedule(Map<String, dynamic> schedule);
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule);
  Future<void> deleteSchedule(String id);

  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> settings);

  Future<Map<String, bool>> getPlatformEnabled();
  Future<void> setPlatformEnabled(String platform, bool enabled);
  Future<List<Map<String, dynamic>>> getMessagingPlatforms() async => [];
  Future<bool> setMessagingPlatformEnabled(String platformId, bool enabled) async => false;
  Future<bool> updateMessagingPlatform(
    String platformId, {
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
  }) async => false;

  Future<Map<String, dynamic>?> getKanbanBoard({String? boardSlug}) async => null;
  Future<bool> createKanbanTask({required String title, String? body, int priority = 0, String? status}) async => false;
  Future<bool> updateKanbanTask(String taskId, {String? status, String? title, String? body}) async => false;
  Future<bool> deleteKanbanTask(String taskId) async => false;

  Future<bool> approveAction({String? requestId}) async => false;
  Future<bool> denyAction({String? requestId}) async => false;

  Future<String> readMemory();
  Future<String> readUserProfile();
  Future<String> readSoul();
  Future<void> writeMemory(String content);
  Future<void> writeUserProfile(String content);
  Future<void> writeSoul(String content);

  Future<Map<String, String>> readEnv();
  Future<void> setEnvValue(String key, String value);

  Future<String> getConfigValue(String path);
  Future<void> setConfigValue(String path, String value);
}

class HermesConnectionFactory {
  static HermesConnection create(ConnectionConfig config) {
    if (config.mode == ConnectionMode.remote) {
      return RemoteConnection(config);
    }
    return SshTunnelConnection(config);
  }
}