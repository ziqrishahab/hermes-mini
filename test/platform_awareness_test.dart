import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/models/connection_config.dart';
import 'package:hermes_mobile/src/services/device_executor_service.dart';
import 'package:hermes_mobile/src/services/remote_connection.dart';

Future<List<Map<String, dynamic>>> _captureHandshake({
  String? sessionId,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final received = <Map<String, dynamic>>[];
  final done = Completer<void>();

  server.listen((req) async {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
      socket.listen((data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        received.add(msg);
        final method = msg['method'];
        if ((method == 'session.create' || method == 'session.resume') &&
            !done.isCompleted) {
          done.complete();
          socket.close();
        }
      });
    } else {
      req.response
        ..statusCode = 404
        ..write('{}');
      await req.response.close();
    }
  });

  final conn = RemoteConnection(
    ConnectionConfig(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
    ),
  );

  try {
    final sub = conn
        .streamChat('hello', sessionId: sessionId)
        .listen((_) {}, onError: (_) {});
    await done.future.timeout(const Duration(seconds: 15));
    await sub.cancel();
  } finally {
    await server.close(force: true);
  }
  return received;
}

class _ConfigServer {
  _ConfigServer({this.initialHints, this.putStatus = 200});

  final Map<String, dynamic>? initialHints;
  final int putStatus;
  late final HttpServer server;
  final puts = <Map<String, dynamic>>[];
  int gets = 0;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/api/config' && req.method == 'GET') {
        gets++;
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              if (initialHints != null) 'platform_hints': initialHints,
            }),
          );
      } else if (req.uri.path == '/api/config' && req.method == 'PUT') {
        puts.add(
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>,
        );
        req.response
          ..statusCode = putStatus
          ..headers.contentType = ContentType.json
          ..write('{"ok": true}');
      } else {
        req.response
          ..statusCode = 404
          ..write('{}');
      }
      await req.response.close();
    });
  }

  RemoteConnection connect() => RemoteConnection(
    ConnectionConfig(
      apiUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
    ),
  );

  Future<void> stop() => server.close(force: true);
}

void platformHintTests() {
  group('Mobile platform hint provisioning', () {
    test('writes platform_hints.mobile when absent', () async {
      final s = _ConfigServer();
      await s.start();
      addTearDown(s.stop);

      final ok = await s.connect().ensureMobilePlatformHint();

      expect(ok, true);
      expect(s.puts, hasLength(1));
      final hints = (s.puts.single['config'] as Map)['platform_hints'] as Map;
      expect(
        (hints['mobile'] as Map)['replace'],
        RemoteConnection.mobilePlatformHint,
      );
      expect(s.puts.single.containsKey('profile'), false);
    });

    test('never overwrites an existing mobile entry', () async {
      final s = _ConfigServer(
        initialHints: {
          'mobile': {'append': 'custom'},
        },
      );
      await s.start();
      addTearDown(s.stop);

      final ok = await s.connect().ensureMobilePlatformHint();

      expect(ok, false);
      expect(s.puts, isEmpty);
    });

    test(
      'checks each profile only once and scopes writes to the profile',
      () async {
        final s = _ConfigServer();
        await s.start();
        addTearDown(s.stop);
        final conn = s.connect();

        await conn.ensureMobilePlatformHint(profile: 'work');
        await conn.ensureMobilePlatformHint(profile: 'work');

        expect(s.gets, 1);
        expect(s.puts, hasLength(1));
        expect(s.puts.single['profile'], 'work');
      },
    );

    test('rejected write is swallowed', () async {
      final s = _ConfigServer(putStatus: 500);
      await s.start();
      addTearDown(s.stop);

      expect(await s.connect().ensureMobilePlatformHint(), false);
    });
  });
}

void main() {
  platformHintTests();

  group('Platform awareness handshake', () {
    test(
      'client.capabilities only carries fields the server contract allows',
      () async {
        final msgs = await _captureHandshake();
        final caps = msgs.firstWhere(
          (m) => m['method'] == 'client.capabilities',
        );
        final params = caps['params'] as Map<String, dynamic>;
        expect(params.keys.toSet(), {'server_requests'});
        expect(params['server_requests'], true);
      },
    );

    test('session.create reports the mobile source', () async {
      final msgs = await _captureHandshake();
      final create = msgs.firstWhere((m) => m['method'] == 'session.create');
      expect(
        (create['params'] as Map)['source'],
        RemoteConnection.clientSource,
      );
      expect(RemoteConnection.clientSource, 'mobile');
    });

    test('session.resume reports the mobile source', () async {
      final msgs = await _captureHandshake(sessionId: 'stored-abc');
      final resume = msgs.firstWhere((m) => m['method'] == 'session.resume');
      final params = resume['params'] as Map;
      expect(params['session_id'], 'stored-abc');
      expect(params['source'], 'mobile');
    });
  });

  group('Device capability announcement', () {
    test('announced only when accessibility is on and not yet announced', () {
      bool f(bool a11y, bool announced) =>
          DeviceExecutorService.shouldAnnounceCapabilities(
            accessibilityEnabled: a11y,
            alreadyAnnounced: announced,
          );
      expect(f(true, false), true);
      expect(f(true, true), false);
      expect(f(false, false), false);
      expect(f(false, true), false);
    });

    test('risky actions stay behind user approval', () {
      for (final a in ['send_whatsapp', 'send_sms', 'call', 'click', 'type']) {
        expect(DeviceExecutorService.isSensitiveAction(a), true, reason: a);
      }
      for (final a in ['read_screen', 'get_device_info', 'vibrate']) {
        expect(DeviceExecutorService.isSensitiveAction(a), false, reason: a);
      }
    });
  });
}
