import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/connection_config.dart';
import '../models/sse_event.dart';
import 'hermes_connection.dart';

class SshConnectionException implements Exception {
  final String message;
  final dynamic cause;
  SshConnectionException(this.message, [this.cause]);
  @override
  String toString() => cause != null ? '$message: $cause' : message;
}

class SshTunnelConnection extends HermesConnection {
  final ConnectionConfig config;
  SSHClient? _client;
  ServerSocket? _localServer;
  final Dio _dio = Dio();
  String? _lastError;

  SshTunnelConnection(this.config);

  Future<SSHClient> _connectSsh() async {
    try {
      final socket = await SSHSocket.connect(
        config.sshHost!,
        config.sshPort ?? 22,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('SSH connection timed out'),
      );

      SSHClient client;
      if (config.usePasswordAuth) {
        client = SSHClient(
          socket,
          username: config.sshUsername!,
          onPasswordRequest: () => config.sshPassword!,
        );
      } else {
        if (config.privateKeyPath == null) {
          throw SshConnectionException('No authentication method provided. Please set either private key or password.');
        }
        final privateKey = await File(config.privateKeyPath!).readAsString();
        final identity = SSHKeyPair.fromPem(privateKey);
        client = SSHClient(
          socket,
          username: config.sshUsername!,
          identities: identity,
        );
      }
      return client;
    } on SshConnectionException {
      rethrow;
    } catch (e) {
      throw SshConnectionException('Failed to connect via SSH', e);
    }
  }

  Future<SSHClient> _getClient() async {
    if (_client != null) return _client!;
    _client = await _connectSsh();
    return _client!;
  }

  Future<String?> _fetchApiKey(SSHClient client) async {
    try {
      final result = await client.run('cat ~/.hermes/.env');
      final envContent = utf8.decode(result);
      return _parseApiKey(envContent);
    } catch (e) {
      _lastError = 'Failed to fetch API key: $e';
      return null;
    }
  }

  String? _parseApiKey(String envContent) {
    for (final line in const LineSplitter().convert(envContent)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('API_SERVER_KEY')) {
        final idx = trimmed.indexOf('=');
        if (idx == -1) continue;
        var value = trimmed.substring(idx + 1).trim();
        if (value.length >= 2) {
          final first = value[0];
          final last = value[value.length - 1];
          if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
            value = value.substring(1, value.length - 1);
          }
        }
        return value.isNotEmpty ? value : null;
      }
    }
    return null;
  }

  Future<String> _sshExec(String command) async {
    try {
      final client = await _getClient();
      final result = await client.run(command);
      return utf8.decode(result);
    } catch (e) {
      throw SshConnectionException('SSH command failed', e);
    }
  }

  Future<String> _sshPython(String script) async {
    // Properly escape single quotes in Python script for shell
    final escaped = script.replaceAll("'", "'\"'\"'");
    return _sshExec("python3 -c '$escaped'");
  }

  // Safe base64 encode for shell commands
  String _safeBase64Encode(String input) {
    return base64Encode(utf8.encode(input));
  }

  // Safe shell escape for strings
  String _shellEscape(String input) {
    // Replace backslash first, then single quotes
    return input.replaceAll('\\', '\\\\').replaceAll("'", "'\"'\"'");
  }

  Future<void> _startLocalForward() async {
    final client = await _getClient();
    final apiKey = await _fetchApiKey(client);
    if (apiKey == null && _lastError != null) {
      throw SshConnectionException(_lastError!);
    }

    final hermesPort = config.remoteHermesPort ?? 8000;

    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _localServer = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      8642,
    );

    _localServer!.listen((socket) {
      client.forwardLocal(
        config.sshHost!,
        hermesPort,
      ).then((forwarded) {
        socket.listen((data) => forwarded.sink.add(data));
        forwarded.stream.listen((data) => socket.add(data));
      }).catchError((_) {
        socket.close();
      });
    });
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _startLocalForward().timeout(const Duration(seconds: 5));
      final response = await _dio
          .get('http://127.0.0.1:8642/health')
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _lastError = 'Connection test failed: $e';
      return false;
    }
  }

  @override
  Future<String> health() async {
    try {
      await _startLocalForward();
      final response = await _dio.get('http://127.0.0.1:8642/health');
      return jsonEncode(response.data);
    } catch (e) {
      throw SshConnectionException('Health check failed', e);
    }
  }

  @override
  Stream<String> streamChat(String message, {String? model, String? sessionId}) async* {
    try {
      await _startLocalForward();
      final response = await _dio.post(
        'http://127.0.0.1:8642/v1/chat/completions',
        data: {
          'model': model ?? 'hermes',
          'messages': [
            {'role': 'user', 'content': message}
          ],
          'stream': true,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final event = SseEvent.fromLine(line);
            if (event.type == 'delta' && event.content != null) {
              yield event.content!;
            } else if (event.type == 'done') {
              return;
            }
          }
        }
      }
    } catch (e) {
      throw SshConnectionException('Stream chat failed', e);
    }
  }

  @override
  Future<bool> stopGeneration({String? sessionId}) async => true;

  @override
  Future<List<SkillInfo>> getSkills() async {
    try {
      final script = '''
import yaml
with open('~/.hermes/config.yaml') as f:
    config = yaml.safe_load(f)
skills = config.get('skills', [])
for skill in skills:
    print(yaml.dump(skill))
''';
      final result = await _sshPython(script);
      final skills = <SkillInfo>[];
      for (final block in result.trim().split('---')) {
        if (block.trim().isEmpty) continue;
        try {
          final data = yamlLoad(block.trim());
          skills.add(SkillInfo.fromJson(data));
        } catch (e) {
          // Skip malformed blocks
          continue;
        }
      }
      return skills;
    } catch (e) {
      throw SshConnectionException('Failed to get skills', e);
    }
  }

  @override
  Future<void> setSkillEnabled(String name, bool enabled) async {
    try {
      // Escape the name parameter to prevent injection
      final escapedName = _shellEscape(name);
      final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for skill in config.get('skills', []):
    if skill.get('name') == '$escapedName':
        skill['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to set skill enabled', e);
    }
  }

  @override
  Future<String> getSkillContent(String skillName) async {
    try {
      final escapedName = _shellEscape(skillName);
      return await _sshExec('cat ~/.hermes/skills/$escapedName.md');
    } catch (e) {
      throw SshConnectionException('Failed to get skill content', e);
    }
  }

  @override
  Future<List<ToolsetInfo>> getToolsets() async {
    try {
      final script = '''
import yaml
with open('~/.hermes/config.yaml') as f:
    config = yaml.safe_load(f)
toolsets = config.get('toolsets', [])
for ts in toolsets:
    print(yaml.dump(ts))
''';
      final result = await _sshPython(script);
      final toolsets = <ToolsetInfo>[];
      for (final block in result.trim().split('---')) {
        if (block.trim().isEmpty) continue;
        try {
          final data = yamlLoad(block.trim());
          toolsets.add(ToolsetInfo.fromJson(data));
        } catch (_) {
          continue;
        }
      }
      return toolsets;
    } catch (e) {
      throw SshConnectionException('Failed to get toolsets', e);
    }
  }

  @override
  Future<void> setToolsetEnabled(String key, bool enabled) async {
    try {
      final escapedKey = _shellEscape(key);
      final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for ts in config.get('toolsets', []):
    if ts.get('key') == '$escapedKey':
        ts['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to set toolset enabled', e);
    }
  }

  @override
  Future<List<ModelConfig>> getModels() async {
    try {
      final script = '''
import yaml
with open('~/.hermes/config.yaml') as f:
    config = yaml.safe_load(f)
providers = config.get('providers', [])
for p in providers:
    print(yaml.dump(p))
''';
      final result = await _sshPython(script);
      final models = <ModelConfig>[];
      for (final block in result.trim().split('---')) {
        if (block.trim().isEmpty) continue;
        try {
          final data = yamlLoad(block.trim());
          models.add(ModelConfig.fromJson(data));
        } catch (_) {
          continue;
        }
      }
      return models;
    } catch (e) {
      throw SshConnectionException('Failed to get models', e);
    }
  }

  @override
  Future<void> setModelEnabled(String name, bool enabled, {String? provider}) async {
    try {
      final escapedName = _shellEscape(name);
      final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for p in config.get('providers', []):
    if p.get('name') == '$escapedName':
        p['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to set model enabled', e);
    }
  }

  @override
  Future<void> setModelProviderKey(String modelName, String provider, String key) async {
    try {
      final escapedModel = _shellEscape(modelName);
      final escapedKey = _shellEscape(key);
      final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for p in config.get('providers', []):
    if p.get('name') == '$escapedModel':
        p['provider_key'] = '$escapedKey'
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to set model provider key', e);
    }
  }

  @override
  Future<List<SessionSummary>> getSessions({String? query}) async {
    try {
      final result = await _sshPython('''
import yaml, os
sessions = []
d = '~/.hermes/sessions'
if os.path.exists(d):
    for f in os.listdir(d):
        if f.endswith('.yaml'):
            with open(os.path.join(d, f)) as fp:
                sessions.append(yaml.safe_load(fp))
for s in sessions:
    print(yaml.dump(s))
''');
      final sessions = <SessionSummary>[];
      for (final block in result.trim().split('---')) {
        if (block.trim().isEmpty) continue;
        try {
          final data = yamlLoad(block.trim());
          if (query == null ||
              (data['title']?.toString().contains(query) ?? false)) {
            sessions.add(SessionSummary.fromJson(data));
          }
        } catch (_) {
          continue;
        }
      }
      return sessions;
    } catch (e) {
      throw SshConnectionException('Failed to get sessions', e);
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    try {
      final escapedId = _shellEscape(id);
      await _sshPython(
        "import os; p='~/.hermes/sessions/$escapedId.yaml'; "
        "os.path.exists(p) and os.remove(p) or None; print('done')");
    } catch (e) {
      throw SshConnectionException('Failed to delete session', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    try {
      final escapedId = _shellEscape(sessionId);
      final content = await _sshExec('cat ~/.hermes/sessions/$escapedId.json');
      if (content.trim().isEmpty) return [];
      try {
        final data = jsonDecode(content);
        if (data is List) return data.cast<Map<String, dynamic>>();
        return [];
      } catch (_) {
        return [];
      }
    } catch (e) {
      throw SshConnectionException('Failed to get session messages', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final result = await _sshPython('''
import yaml
with open('~/.hermes/config.yaml') as f:
    config = yaml.safe_load(f)
for s in config.get('schedules', []):
    print(yaml.dump(s))
''');
      final schedules = <Map<String, dynamic>>[];
      for (final block in result.trim().split('---')) {
        if (block.trim().isEmpty) continue;
        try {
          schedules.add(yamlLoad(block.trim()));
        } catch (_) {
          continue;
        }
      }
      return schedules;
    } catch (e) {
      throw SshConnectionException('Failed to get schedules', e);
    }
  }

  @override
  Future<void> createSchedule(Map<String, dynamic> schedule) async {
    try {
      // Use base64 to safely pass schedule data
      final scheduleJson = jsonEncode(schedule);
      final encoded = _safeBase64Encode(scheduleJson);
      final script = '''
import yaml, json, base64
d = json.loads(base64.b64decode('$encoded').decode())
with open('~/.hermes/config.yaml', 'r') as f:
    c = yaml.safe_load(f)
c.setdefault('schedules', []).append(d)
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(c, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to create schedule', e);
    }
  }

  @override
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule) async {
    try {
      final scheduleJson = jsonEncode(schedule);
      final encoded = _safeBase64Encode(scheduleJson);
      final escapedId = _shellEscape(id);
      final script = '''
import yaml, json, base64
d = json.loads(base64.b64decode('$encoded').decode())
with open('~/.hermes/config.yaml', 'r') as f:
    c = yaml.safe_load(f)
for i, s in enumerate(c.get('schedules', [])):
    if s.get('id') == '$escapedId':
        c['schedules'][i] = d
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(c, f)
print('done')
''';
      await _sshPython(script);
    } catch (e) {
      throw SshConnectionException('Failed to update schedule', e);
    }
  }

  @override
  Future<void> deleteSchedule(String id) async {
    try {
      final escapedId = _shellEscape(id);
      await _sshPython('''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    c = yaml.safe_load(f)
c['schedules'] = [s for s in c.get('schedules', []) if s.get('id') != '$escapedId']
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(c, f)
print('done')
''');
    } catch (e) {
      throw SshConnectionException('Failed to delete schedule', e);
    }
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final content = await _sshExec('cat ~/.hermes/config.yaml');
      return {'raw': content};
    } catch (e) {
      throw SshConnectionException('Failed to get settings', e);
    }
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    throw SshConnectionException('Settings update not implemented');
  }

  @override
  Future<Map<String, bool>> getPlatformEnabled() async {
    return {};
  }

  @override
  Future<void> setPlatformEnabled(String platform, bool enabled) async {
    throw SshConnectionException('Platform enable not implemented');
  }

  @override
  Future<String> readMemory() async {
    try {
      return await _sshExec('cat ~/.hermes/memory.md');
    } catch (e) {
      throw SshConnectionException('Failed to read memory', e);
    }
  }

  @override
  Future<String> readUserProfile() async {
    try {
      return await _sshExec('cat ~/.hermes/user.md 2>/dev/null || cat ~/.hermes/user_profile.md 2>/dev/null');
    } catch (e) {
      throw SshConnectionException('Failed to read user profile', e);
    }
  }

  @override
  Future<String> readSoul() async {
    try {
      return await _sshExec('cat ~/.hermes/soul.md 2>/dev/null || cat ~/.hermes/SOUL.md 2>/dev/null');
    } catch (e) {
      throw SshConnectionException('Failed to read soul configuration', e);
    }
  }

  @override
  Future<void> writeMemory(String content) async {
    try {
      final encoded = _safeBase64Encode(content);
      await _sshExec("echo '$encoded' | base64 -d > ~/.hermes/memory.md");
    } catch (e) {
      throw SshConnectionException('Failed to write memory', e);
    }
  }

  @override
  Future<void> writeUserProfile(String content) async {
    try {
      final encoded = _safeBase64Encode(content);
      await _sshExec("echo '$encoded' | base64 -d > ~/.hermes/user.md; echo '$encoded' | base64 -d > ~/.hermes/user_profile.md");
    } catch (e) {
      throw SshConnectionException('Failed to write user profile', e);
    }
  }

  @override
  Future<void> writeSoul(String content) async {
    try {
      final encoded = _safeBase64Encode(content);
      await _sshExec("echo '$encoded' | base64 -d > ~/.hermes/soul.md");
    } catch (e) {
      throw SshConnectionException('Failed to write soul configuration', e);
    }
  }

  @override
  Future<Map<String, String>> readEnv() async {
    try {
      final content = await _sshExec('cat ~/.hermes/.env');
      final result = <String, String>{};
      for (final line in const LineSplitter().convert(content)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final idx = trimmed.indexOf('=');
        if (idx == -1) continue;
        final key = trimmed.substring(0, idx).trim();
        var value = trimmed.substring(idx + 1).trim();
        if (value.length >= 2 &&
            ((value[0] == '"' && value[value.length - 1] == '"') ||
             (value[0] == "'" && value[value.length - 1] == "'"))) {
          value = value.substring(1, value.length - 1);
        }
        result[key] = value;
      }
      return result;
    } catch (e) {
      throw SshConnectionException('Failed to read env', e);
    }
  }

  @override
  Future<void> setEnvValue(String key, String value) async {
    try {
      final escapedKey = _shellEscape(key);
      final escapedValue = _shellEscape(value);
      await _sshExec("sed -i 's/^$escapedKey=.*/$escapedKey=$escapedValue/' ~/.hermes/.env");
    } catch (e) {
      throw SshConnectionException('Failed to set env value', e);
    }
  }

  @override
  Future<String> getConfigValue(String path) async {
    try {
      final escapedPath = _shellEscape(path);
      return await _sshExec('cat ~/$escapedPath');
    } catch (e) {
      throw SshConnectionException('Failed to get config value', e);
    }
  }

  @override
  Future<void> setConfigValue(String path, String value) async {
    try {
      final encoded = _safeBase64Encode(value);
      final escapedPath = _shellEscape(path);
      await _sshExec("echo '$encoded' | base64 -d > ~/$escapedPath");
    } catch (e) {
      throw SshConnectionException('Failed to set config value', e);
    }
  }

  @override
  void dispose() {
    _client?.close();
    _localServer?.close();
    _client = null;
    _localServer = null;
  }
}

// YAML helpers
Map<String, dynamic> yamlLoad(String content) {
  final result = <String, dynamic>{};
  for (final line in const LineSplitter().convert(content)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf(':');
    if (idx == -1) continue;
    final key = trimmed.substring(0, idx).trim();
    var value = trimmed.substring(idx + 1).trim();
    if (value == 'true') {
      result[key] = true;
    } else if (value == 'false') {
      result[key] = false;
    } else if (int.tryParse(value) != null) {
      result[key] = int.parse(value);
    } else {
      if (value.length >= 2 &&
          ((value[0] == '"' && value[value.length - 1] == '"') ||
           (value[0] == "'" && value[value.length - 1] == "'"))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
  }
  return result;
}

String yamlDump(Map<String, dynamic> data) {
  final buf = StringBuffer();
  for (final e in data.entries) {
    final v = e.value;
    if (v is String) {
      buf.writeln('${e.key}: "${v.replaceAll('"', '\\"')}"');
    } else {
      buf.writeln('${e.key}: $v');
    }
  }
  return buf.toString().trim();
}
