class AgentProfile {
  final String id;
  final String name;
  final String? model;
  final String? provider;
  final bool isDefault;
  final int skillCount;
  final bool hasEnv;
  final bool gatewayRunning;

  const AgentProfile({
    required this.id,
    required this.name,
    this.model,
    this.provider,
    this.isDefault = false,
    this.skillCount = 0,
    this.hasEnv = false,
    this.gatewayRunning = false,
  });

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    final rawId = (json['name'] as String?)?.trim() ??
        (json['id'] as String?)?.trim() ??
        '';
    final effectiveId = rawId.isNotEmpty ? rawId : 'default';

    final rawDisplay = (json['display_name'] as String?)?.trim() ??
        (json['label'] as String?)?.trim() ??
        '';
    final String effectiveName;
    if (rawDisplay.isNotEmpty) {
      effectiveName = rawDisplay;
    } else if (effectiveId == 'default') {
      effectiveName = 'Default Agent';
    } else {
      effectiveName = effectiveId;
    }

    return AgentProfile(
      id: effectiveId,
      name: effectiveName,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      isDefault: json['is_default'] as bool? ?? (effectiveId == 'default'),
      skillCount: (json['skill_count'] as num?)?.toInt() ?? 0,
      hasEnv: json['has_env'] as bool? ?? false,
      gatewayRunning: json['gateway_running'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': id,
        'display_name': name,
        'model': model,
        'provider': provider,
        'is_default': isDefault,
        'skill_count': skillCount,
        'has_env': hasEnv,
        'gateway_running': gatewayRunning,
      };

  static String canonicalizeId(String input) {
    var id = input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
    id = id.replaceAll(RegExp(r'^-+|-+$'), '');
    if (id.length > 64) {
      id = id.substring(0, 64).replaceAll(RegExp(r'^-+|-+$'), '');
    }
    return id;
  }

  static bool isValidId(String id) {
    return RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id);
  }
}
