import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/models/connection_config.dart';
import 'package:hermes_mobile/src/services/hermes_connection.dart';
import 'package:hermes_mobile/src/ui/screens/schedules_screen.dart';

void main() {
  group('ConnectionConfig', () {
    test('isComplete returns true for valid remote config', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.remote,
        apiUrl: 'https://example.com',
        apiKey: 'test-key',
      );
      expect(config.isComplete, isTrue);
    });

    test('isComplete returns false for empty apiUrl', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.remote,
        apiUrl: '',
        apiKey: 'test-key',
      );
      expect(config.isComplete, isFalse);
    });

    test('isComplete returns false for empty apiKey', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.remote,
        apiUrl: 'https://example.com',
        apiKey: '',
      );
      expect(config.isComplete, isFalse);
    });

    test('isComplete returns true for valid SSH config with key', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.sshTunnel,
        sshHost: 'example.com',
        sshUsername: 'user',
        privateKeyPath: '/path/to/key',
      );
      expect(config.isComplete, isTrue);
    });

    test('isComplete returns true for valid SSH config with password', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.sshTunnel,
        sshHost: 'example.com',
        sshUsername: 'user',
        sshPassword: 'password',
      );
      expect(config.isComplete, isTrue);
    });

    test('isComplete returns false for SSH without auth', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.sshTunnel,
        sshHost: 'example.com',
        sshUsername: 'user',
      );
      expect(config.isComplete, isFalse);
    });

    test('usePasswordAuth returns true when password is set', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.sshTunnel,
        sshHost: 'example.com',
        sshUsername: 'user',
        sshPassword: 'password',
      );
      expect(config.usePasswordAuth, isTrue);
    });

    test('usePasswordAuth returns false when only key is set', () {
      const config = ConnectionConfig(
        mode: ConnectionMode.sshTunnel,
        sshHost: 'example.com',
        sshUsername: 'user',
        privateKeyPath: '/path/to/key',
      );
      expect(config.usePasswordAuth, isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      const original = ConnectionConfig(
        mode: ConnectionMode.remote,
        apiUrl: 'https://old.com',
        apiKey: 'old-key',
      );
      final updated = original.copyWith(
        apiUrl: 'https://new.com',
        apiKey: 'new-key',
      );
      expect(updated.apiUrl, 'https://new.com');
      expect(updated.apiKey, 'new-key');
      expect(updated.mode, ConnectionMode.remote);
    });

    test('toJson and fromJson roundtrip', () {
      const original = ConnectionConfig(
        mode: ConnectionMode.remote,
        apiUrl: 'https://example.com',
        apiKey: 'test-key',
      );
      final json = original.toJson();
      final restored = ConnectionConfig.fromJson(json);
      expect(restored.mode, original.mode);
      expect(restored.apiUrl, original.apiUrl);
      expect(restored.apiKey, original.apiKey);
    });
  });

  group('HermesConnection Models', () {
    test('SkillInfo fromJson creates valid instance', () {
      final json = {
        'name': 'test-skill',
        'category': 'test-category',
        'description': 'Test description',
        'path': '/path/to/skill',
        'enabled': true,
      };
      final skill = SkillInfo.fromJson(json);
      expect(skill.name, 'test-skill');
      expect(skill.category, 'test-category');
      expect(skill.description, 'Test description');
      expect(skill.path, '/path/to/skill');
      expect(skill.enabled, true);
    });

    test('SkillInfo handles missing fields', () {
      final json = <String, dynamic>{};
      final skill = SkillInfo.fromJson(json);
      expect(skill.name, '');
      expect(skill.category, '');
      expect(skill.description, '');
      expect(skill.path, '');
      expect(skill.enabled, true);
    });

    test('ToolsetInfo fromJson creates valid instance', () {
      final json = {
        'key': 'test-toolset',
        'label': 'Test Toolset',
        'description': 'Test description',
        'enabled': false,
      };
      final toolset = ToolsetInfo.fromJson(json);
      expect(toolset.key, 'test-toolset');
      expect(toolset.label, 'Test Toolset');
      expect(toolset.enabled, false);
    });

    test('ModelConfig fromJson creates valid instance', () {
      final json = {
        'name': 'gpt-4',
        'provider': 'openai',
        'model': 'gpt-4',
        'baseUrl': 'https://api.openai.com',
        'enabled': true,
      };
      final model = ModelConfig.fromJson(json);
      expect(model.name, 'gpt-4');
      expect(model.provider, 'openai');
      expect(model.model, 'gpt-4');
      expect(model.baseUrl, 'https://api.openai.com');
      expect(model.enabled, true);
    });

    test('ModelConfig uses model field as name fallback', () {
      final json = {
        'model': 'claude-3',
        'provider': 'anthropic',
      };
      final model = ModelConfig.fromJson(json);
      expect(model.name, 'claude-3');
    });

    test('SessionSummary fromJson creates valid instance', () {
      final json = {
        'id': 'session-123',
        'title': 'Test Session',
        'startedAt': '2024-01-01T00:00:00Z',
        'source': 'mobile',
        'messageCount': 10,
        'model': 'gpt-4',
      };
      final session = SessionSummary.fromJson(json);
      expect(session.id, 'session-123');
      expect(session.title, 'Test Session');
      expect(session.startedAt, '2024-01-01T00:00:00Z');
      expect(session.source, 'mobile');
      expect(session.messageCount, 10);
      expect(session.model, 'gpt-4');
    });
  });

  group('CronValidator', () {
    test('validates correct cron expressions', () {
      expect(CronValidator.validate('0 9 * * *'), isNull);
      expect(CronValidator.validate('*/5 * * * *'), isNull);
      expect(CronValidator.validate('0 0 1 1 *'), isNull);
      expect(CronValidator.validate('30 4 15 * *'), isNull);
    });

    test('rejects empty cron', () {
      expect(CronValidator.validate(''), isNotNull);
      expect(CronValidator.validate(null), isNotNull);
    });

    test('rejects invalid cron format', () {
      expect(CronValidator.validate('invalid'), isNotNull);
      expect(CronValidator.validate('0 0 0'), isNotNull);
      expect(CronValidator.validate('* * * * * *'), isNotNull);
    });

    test('rejects invalid minute values', () {
      expect(CronValidator.validate('60 9 * * *'), isNotNull);
      expect(CronValidator.validate('-1 9 * * *'), isNotNull);
    });

    test('rejects invalid hour values', () {
      expect(CronValidator.validate('0 25 * * *'), isNotNull);
      expect(CronValidator.validate('0 -1 * * *'), isNotNull);
    });

    test('toHumanReadable returns correct format for common patterns', () {
      expect(CronValidator.toHumanReadable('0 9 * * *'), 'Daily at 9:00 AM');
      expect(CronValidator.toHumanReadable('0 0 * * *'), 'Daily at midnight');
      expect(CronValidator.toHumanReadable('0 12 * * *'), 'Daily at noon');
      expect(CronValidator.toHumanReadable('* * * * *'), 'Every minute');
    });

    test('toHumanReadable handles interval patterns', () {
      expect(CronValidator.toHumanReadable('*/5 * * * *'), 'Every 5 minutes');
      expect(CronValidator.toHumanReadable('*/2 * * * *'), 'Every 2 minutes');
      expect(CronValidator.toHumanReadable('0 */3 * * *'), 'Every 3 hours');
    });

    test('toHumanReadable returns cron for uncommon patterns', () {
      expect(CronValidator.toHumanReadable('30 14 5 6 *'), '30 14 5 6 *');
    });
  });
}
