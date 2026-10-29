enum HealthSeverity {
  healthy,
  warning,
  error,
}

class ConfigHealthItem {
  final String title;
  final String description;
  final HealthSeverity severity;
  final String category;
  final bool autoFixable;

  const ConfigHealthItem({
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    this.autoFixable = false,
  });

  factory ConfigHealthItem.fromJson(Map<String, dynamic> json) {
    HealthSeverity severity;
    final sevStr = (json['severity'] as String? ?? 'info').toLowerCase();
    if (sevStr == 'error') {
      severity = HealthSeverity.error;
    } else if (sevStr == 'warning') {
      severity = HealthSeverity.warning;
    } else {
      severity = HealthSeverity.healthy;
    }

    return ConfigHealthItem(
      title: json['title'] as String? ?? json['code'] as String? ?? 'Check',
      description: json['message'] as String? ?? json['description'] as String? ?? '',
      severity: severity,
      category: json['category'] as String? ?? 'System',
      autoFixable: json['autoFixable'] as bool? ?? false,
    );
  }
}
