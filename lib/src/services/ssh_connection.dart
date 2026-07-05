import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/connection_config.dart';
import '../models/sse_event.dart';
import 'hermes_connection.dart';

class SshTunnelConnection extends HermesConnection {
  final ConnectionConfig config;
  SSHClient? _client;
  ServerSocket? _localServer;
  final Dio _dio = Dio();

  SshTunnelConnection(this.config);

  Future<SSHClient> _connectSsh() async {
    final privateKey = await File(config.privateKeyPath!).readAsString();
    final identity = SSHKeyPair.fromPem(privateKey);
    final socket = await SSHSocket.connect(
      config.sshHost!,
      config.sshPort ?? 22,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('SSH connection timed out'),
    );
    final client = SSHClient(
      socket,
      username: config.sshUsername!,
      identities: identity,
      onPasswordRequest: () => '',
    );
    return client;
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
    } catch (_) {
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
    final client = await _getClient();
    final result = await client.run(command);
    return utf8.decode(result);
  }

  Future<String> _sshPython(String script) async {
    final escaped = script.replaceAll("'", "'\\''");
    return _sshExec("python3 -c '$escaped'");
  }

  Future<void> _startLocalForward() async {
    final client = await _getClient();
    final apiKey = await _fetchApiKey(client);
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
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> health() async {
    await _startLocalForward();
    final response = await _dio.get('http://127.0.0.1:8642/health');
    return jsonEncode(response.data);
  }

  @override
  Stream<String> streamChat(String message, {String? model}) async* {
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
  }

  @override
  Future<List<SkillInfo>> getSkills() async {
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
      } catch (_) {}
    }
    return skills;
  }

  @override
  Future<void> setSkillEnabled(String name, bool enabled) async {
    final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for skill in config.get('skills', []):
    if skill.get('name') == '$name':
        skill['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
    await _sshPython(script);
  }

  @override
  Future<String> getSkillContent(String skillName) async {
    return _sshExec('cat ~/.hermes/skills/$skillName.md');
  }

  @override
  Future<List<ToolsetInfo>> getToolsets() async {
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
      } catch (_) {}
    }
    return toolsets;
  }

  @override
  Future<void> setToolsetEnabled(String key, bool enabled) async {
    final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for ts in config.get('toolsets', []):
    if ts.get('key') == '$key':
        ts['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
    await _sshPython(script);
  }

  @override
  Future<List<ModelConfig>> getModels() async {
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
      } catch (_) {}
    }
    return models;
  }

  @override
  Future<void> setModelEnabled(String name, bool enabled) async {
    final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for p in config.get('providers', []):
    if p.get('name') == '$name':
        p['enabled'] = $enabled
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
    await _sshPython(script);
  }

  @override
  Future<void> setModelProviderKey(
      String modelName, String provider, String key) async {
    final script = '''
import yaml
with open('~/.hermes/config.yaml', 'r') as f:
    config = yaml.safe_load(f)
for p in config.get('providers', []):
    if p.get('name') == '$modelName':
        p['provider_key'] = '$key'
        break
with open('~/.hermes/config.yaml', 'w') as f:
    yaml.dump(config, f)
print('done')
''';
    await _sshPython(script);
  }

  @override
  Future<List<SessionSummary>> getSessions({String? query}) async {
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
      } catch (_) {}
    }
    return sessions;
  }

  @override
  Future<void> deleteSession(String id) async {
    await _sshPython(
        "import os; p='~/.hermes/sessions/$id.yaml'; "
        "os.path.exists(p) and os.remove(p) or None; print('done')");
  }

  @override
  Future<List<Map<String, dynamic>>> getSessionMessages(String sessionId) async {
    final content =
        await _sshExec('cat ~/.hermes/sessions/$sessionId.json');
    if (content.trim().isEmpty) return [];
    try {
      final data = jsonDecode(content);
      if (data is List) return data.cast<Map<String, dynamic>>();
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSchedules() async {
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
      } catch (_) {}
    }
    return schedules;
  }

  @override
  Future<void> createSchedule(Map<String, dynamic> schedule) async {
    final encoded = base64Encode(utf8.encode(jsonEncode(schedule)));
    await _sshPython(
        "import yaml,json,base64; "
        "d=json.loads(base64.b64decode('$encoded').decode());"
        "with open('~/.hermes/config.yaml','r') as f: c=yaml.safe_load(f);"
        "c.setdefault('schedules',[]).append(d);"
        "with open('~/.hermes/config.yaml','w') as f: yaml.dump(c,f);"
        "print('done')");
  }

  @override
  Future<void> updateSchedule(String id, Map<String, dynamic> schedule) async {
    final encoded = base64Encode(utf8.encode(jsonEncode(schedule)));
    await _sshPython(
        "import yaml,json,base64; "
        "d=json.loads(base64.b64decode('$encoded').decode());"
        "with open('~/.hermes/config.yaml','r') as f: c=yaml.safe_load(f);"
        "for i,s in enumerate(c.get('schedules',[])):"
        " if s.get('id')=='$id':c['schedules'][i]=d;break;"
        "with open('~/.hermes/config.yaml','w') as f: yaml.dump(c,f);"
        "print('done')");
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await _sshPython(
        "import yaml;"
        "with open('~/.hermes/config.yaml','r') as f: c=yaml.safe_load(f);"
        "c['schedules']=[s for s in c.get('schedules',[]) if s.get('id')!='$id'];"
        "with open('~/.hermes/config.yaml','w') as f: yaml.dump(c,f);"
        "print('done')");
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    final content = await _sshExec('cat ~/.hermes/config.yaml');
    return {'raw': content};
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    // ponytail: needs YAML merge, add when settings UI is finalized
  }

  @override
  Future<Map<String, bool>> getPlatformEnabled() async => {};

  @override
  Future<void> setPlatformEnabled(String platform, bool enabled) async {}

  @override
  Future<String> readMemory() async => _sshExec('cat ~/.hermes/memory.md');

  @override
  Future<String> readUserProfile() async => _sshExec('cat ~/.hermes/user_profile.md');

  @override
  Future<void> writeMemory(String content) async {
    final encoded = base64Encode(utf8.encode(content));
    await _sshExec("echo '$encoded' | base64 -d > ~/.hermes/memory.md");
  }

  @override
  Future<void> writeUserProfile(String content) async {
    final encoded = base64Encode(utf8.encode(content));
    await _sshExec("echo '$encoded' | base64 -d > ~/.hermes/user_profile.md");
  }

  @override
  Future<Map<String, String>> readEnv() async {
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
  }

  @override
  Future<void> setEnvValue(String key, String value) async {
    await _sshExec("sed -i 's/^$key=.*/$key=$value/' ~/.hermes/.env");
  }

  @override
  Future<String> getConfigValue(String path) async => _sshExec('cat ~/$path');

  @override
  Future<void> setConfigValue(String path, String value) async {
    final encoded = base64Encode(utf8.encode(value));
    await _sshExec("echo '$encoded' | base64 -d > ~/$path");
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
