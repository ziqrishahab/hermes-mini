import 'dart:async';
import 'remote_connection.dart';
import '../models/connection_config.dart';
import '../models/agent_profile.dart';
import '../models/config_health_item.dart';

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
  final String profile;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.source,
    required this.messageCount,
    required this.model,
    this.snippet = '',
    this.unreadCount = 0,
    this.profile = 'default',
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

    final rawSnippet = json['last_message'] ??
        json['lastMessage'] ??
        json['last_message_content'] ??
        json['snippet'] ??
        json['preview'] ??
        '';

    return SessionSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Session',
      startedAt: startedAtStr,
      source: json['source'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? json['message_count'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      snippet: rawSnippet.toString(),
      unreadCount: unread,
      profile: (json['profile'] as String?)?.trim().isNotEmpty == true
          ? (json['profile'] as String).trim()
          : 'default',
    );
  }

  SessionSummary copyWith({
    String? id,
    String? title,
    String? startedAt,
    String? source,
    int? messageCount,
    String? model,
    String? snippet,
    int? unreadCount,
    String? profile,
  }) {
    return SessionSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      source: source ?? this.source,
      messageCount: messageCount ?? this.messageCount,
      model: model ?? this.model,
      snippet: snippet ?? this.snippet,
      unreadCount: unreadCount ?? this.unreadCount,
      profile: profile ?? this.profile,
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
        'profile': profile,
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
  String get activeProfile => 'default';
  set activeProfile(String profile) {}

  Stream<String> streamChat(String message, {String? model, String? sessionId, String? profile});
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
  Future<List<Map<String, dynamic>>> getPluginCatalog() async => [];
  Future<bool> installPlugin(String name) async => false;
  Future<bool> setPluginEnabled(String name, bool enabled) async => false;
  Future<bool> uninstallPlugin(String name) async => false;
  Future<Map<String, dynamic>?> getPluginApi(String pluginName, String path) async => null;
  Future<Map<String, dynamic>?> getSystemStats() async => null;
  String? get lastPluginError => null;
  Future<String> executeSlashCommand(String command, {String? sessionId}) async => '';

  Future<List<ModelConfig>> getModels({String? profile});
  Future<void> setModelEnabled(String name, bool enabled, {String? provider, String? profile});
  Future<void> setModelProviderKey(String modelName, String provider, String key, {String? profile});
  Future<bool> setCustomInferenceEndpoint({
    required String baseUrl,
    required String apiKey,
    String? model,
    String? provider,
    String? profile,
  }) async => false;
  Future<Map<String, dynamic>> getModelInfo({String? profile}) async => {};
  Future<bool> respondApproval(String choice) async => false;
  String? get lastModelFetchError => null;

  Future<String> getReasoningEffort() async => 'low';
  Future<bool> setReasoningEffort(String effort) async => false;
  Future<String?> getActiveWorkspaceCwd() async => null;
  Future<bool> setActiveWorkspaceCwd(String path) async => false;
  Future<List<Map<String, dynamic>>> getProjectsList() async => [];
  Future<List<Map<String, dynamic>>> listWorkspaceFiles({String? subpath}) async => [];
  Future<String?> readWorkspaceFile(String path) async => null;
  Future<bool> writeWorkspaceFile(String path, String content) async => false;
  Future<List<Map<String, dynamic>>> getCronJobRuns(String id) async => [];
  Future<Map<String, dynamic>?> getWhatsAppBridgeStatus() async => null;

  Future<List<SessionSummary>> getSessions({String? query});
  Future<void> deleteSession(String id, {String? profile});
  Future<void> renameSession(String id, String newTitle, {String? profile}) async {}
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId, {String? profile});

  Future<List<Map<String, dynamic>>> getSchedules();
  Future<void> createSchedule(Map<String, dynamic> schedule);
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule);
  Future<void> deleteSchedule(String id);
  Future<bool> triggerSchedule(String id) async => false;

  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> settings);
  Future<void> clearLocalCache() async {}

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

  Future<String> readMemory({String? profile});
  Future<String> readUserProfile();
  Future<String> readSoul({String? profile});
  Future<void> writeMemory(String content, {String? profile});
  Future<void> writeUserProfile(String content);
  Future<void> writeSoul(String content, {String? profile});

  Future<List<AgentProfile>> listProfiles() async => [];
  Future<bool> createProfile(
    String name, {
    String? cloneFrom,
    String? description,
    void Function(String error)? onError,
  }) async =>
      false;
  Future<bool> deleteProfile(String name) async => false;
  Future<bool> switchServerProfile(String name) async => false;
  Future<bool> installSkill(String identifier, {String? profile}) async => false;
  Future<List<ConfigHealthItem>> runConfigHealthAudit() async => [];

  Future<Map<String, String>> readEnv({String? profile});
  Future<void> setEnvValue(String key, String value, {String? profile});

  Future<String> getConfigValue(String path, {String? profile});
  Future<void> setConfigValue(String path, String value, {String? profile});
}

class HermesConnectionFactory {
  static HermesConnection create(ConnectionConfig config) {
    return RemoteConnection(config);
  }
}
