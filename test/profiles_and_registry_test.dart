import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/models/agent_profile.dart';
import 'package:hermes_mobile/src/models/registry_item.dart';
import 'package:hermes_mobile/src/models/config_health_item.dart';
import 'package:hermes_mobile/src/services/registry_service.dart';

void main() {
  group('AgentProfile Tests', () {
    test('fromJson sets default values properly', () {
      final profile = AgentProfile.fromJson({
        'name': 'coder',
        'display_name': 'Code Specialist',
        'model': 'claude-3-7-sonnet',
        'skill_count': 5,
      });

      expect(profile.id, 'coder');
      expect(profile.name, 'Code Specialist');
      expect(profile.model, 'claude-3-7-sonnet');
      expect(profile.isDefault, false);
      expect(profile.skillCount, 5);
    });

    test('fromJson falls back when display_name is empty string', () {
      final defaultProfile = AgentProfile.fromJson({
        'name': 'default',
        'display_name': '',
        'model': 'inkling:free',
        'skill_count': 58,
      });
      expect(defaultProfile.id, 'default');
      expect(defaultProfile.name, 'Default Agent');

      final customProfile = AgentProfile.fromJson({
        'name': 'researcher',
        'display_name': '',
      });
      expect(customProfile.id, 'researcher');
      expect(customProfile.name, 'researcher');
    });

    test('toJson produces valid roundtrip payload', () {
      const profile = AgentProfile(
        id: 'analyst',
        name: 'Data Analyst',
        model: 'gpt-4o',
        provider: 'openai',
        isDefault: false,
        skillCount: 3,
      );

      final json = profile.toJson();
      expect(json['name'], 'analyst');
      expect(json['display_name'], 'Data Analyst');
      expect(json['model'], 'gpt-4o');
      expect(json['provider'], 'openai');
      expect(json['skill_count'], 3);
    });
  });

  group('RegistryItem Tests', () {
    test('fromJson parses skill item with tags', () {
      final item = RegistryItem.fromJson({
        'id': 'web-search',
        'name': 'Live Web Search',
        'description': 'Search and summarize documents',
        'type': 'skill',
        'author': 'hermes',
        'category': 'search',
        'tags': ['web', 'search'],
      });

      expect(item.id, 'web-search');
      expect(item.name, 'Live Web Search');
      expect(item.type, 'skill');
      expect(item.tags.length, 2);
    });

    test('RegistryService fallback catalog is populated', () async {
      final catalog = await RegistryService.fetchCatalog();
      expect(catalog.isNotEmpty, true);
      expect(catalog.any((i) => i.id == 'browser'), true);
      expect(catalog.any((i) => i.type == 'mcp'), true);
    });
  });

  group('ConfigHealthItem Tests', () {
    test('parses severity correctly', () {
      final errorItem = ConfigHealthItem.fromJson({
        'title': 'API Key Missing',
        'description': 'Key is blank',
        'severity': 'error',
        'category': 'Inference',
      });
      expect(errorItem.severity, HealthSeverity.error);

      final warnItem = ConfigHealthItem.fromJson({
        'title': 'Soul Empty',
        'description': 'SOUL.md is blank',
        'severity': 'warning',
        'category': 'Persona',
      });
      expect(warnItem.severity, HealthSeverity.warning);

      final healthyItem = ConfigHealthItem.fromJson({
        'title': 'Gateway',
        'description': 'Online',
        'severity': 'healthy',
        'category': 'Network',
      });
      expect(healthyItem.severity, HealthSeverity.healthy);
    });
  });
}
