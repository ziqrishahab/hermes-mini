import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/src/providers/chat_provider.dart';
import 'package:hermes_mobile/src/services/device_executor_service.dart';
import 'package:hermes_mobile/src/services/shell_executor_service.dart';
import 'package:hermes_mobile/src/ui/screens/settings_screen.dart';
import 'package:hermes_mobile/src/ui/widgets/fluid_pulse_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ShellExecutorService.channel, null);
  });

  group('ShellExecutorService safety guardrails', () {
    test('allows safe diagnostic and Android management commands', () {
      const safeCommands = [
        'dumpsys battery',
        'pm list packages -3',
        'logcat -d -t 50',
        'getprop ro.build.version.release',
        'am start -a android.intent.action.VIEW',
        'screencap -p /sdcard/Download/screen.png',
        'rm /sdcard/Download/temp_shot.png',
      ];
      for (final cmd in safeCommands) {
        expect(ShellExecutorService.validateCommand(cmd), isNull, reason: cmd);
      }
    });

    test('blocks destructive, bricking, and self-sabotage commands', () {
      const dangerousCommands = [
        '   ',
        ':(){ :|:& };:',
        'rm -rf /',
        'rm -rf /sdcard',
        'rm -rf /sdcard/*',
        'rm -fr /storage',
        'rm --no-preserve-root -rf /',
        'dd if=/dev/zero of=/dev/block/by-name/boot',
        'mkfs.ext4 /dev/block/sda1',
        'reboot',
        'reboot bootloader',
        'reboot fastboot',
        'am broadcast -a android.intent.action.MASTER_CLEAR',
        'recovery --wipe_data',
        'locksettings clear --old 1234',
        'pm uninstall com.hermesmobile.hermes_mobile',
        'pm disable-user moe.shizuku.privileged.api',
      ];
      for (final cmd in dangerousCommands) {
        expect(
          ShellExecutorService.validateCommand(cmd),
          isNotNull,
          reason: 'Expected "$cmd" to be blocked',
        );
      }
    });

    test('blocked command never reaches native MethodChannel', () async {
      var nativeInvoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ShellExecutorService.channel, (call) async {
        nativeInvoked = true;
        return null;
      });

      final res = await DeviceExecutorService.execute(
        'adb_shell',
        {'command': 'rm -rf /sdcard'},
      );

      expect(nativeInvoked, false);
      expect(res.success, false);
      expect(res.message, contains('Blocked for device safety'));
      expect(res.data?['blocked'], true);
    });
  });

  group('Shizuku Next IPC execution', () {
    test('parses Shizuku UID 2000 status and executes shell command', () async {
      MethodCall? capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ShellExecutorService.channel, (call) async {
        if (call.method == 'getStatus') {
          return {
            'available': true,
            'running': true,
            'authorized': true,
            'backend': 'shizuku',
            'installedBackend': 'shizuku',
            'uid': 2000,
            'modeLabel': 'Active (ADB UID 2000 via Shizuku)',
          };
        }
        if (call.method == 'executeCommand') {
          capturedCall = call;
          return {
            'success': true,
            'exitCode': 0,
            'stdout': 'level: 87\nstatus: 2',
            'stderr': '',
            'timedOut': false,
            'backend': 'shizuku',
          };
        }
        return null;
      });

      final status = await ShellExecutorService.getStatus();
      expect(status.authorized, true);
      expect(status.backend, 'shizuku');
      expect(status.uid, 2000);

      final res = await DeviceExecutorService.execute(
        'adb_shell',
        {'command': 'dumpsys battery', 'timeout_ms': 10000},
      );

      expect(capturedCall?.arguments['command'], 'dumpsys battery');
      expect(capturedCall?.arguments['timeoutMs'], 10000);
      expect(res.success, true);
      expect(res.message, contains('level: 87'));
      expect(res.data?['backend'], 'shizuku');
      expect(res.data?['stdout'], 'level: 87\nstatus: 2');
    });

    test('adb_shell is classified sensitive and builds clear confirmation text', () {
      expect(DeviceExecutorService.isSensitiveAction('adb_shell'), true);
      expect(DeviceExecutorService.isSensitiveAction('check_shell'), false);

      final summary = DeviceExecutorService.getActionSummary(
        'adb_shell',
        {'command': 'pm list packages -3'},
      );
      expect(summary, contains('pm list packages -3'));

      expect(
        DeviceExecutorService.shouldAnnounceCapabilities(
          accessibilityEnabled: false,
          shellAuthorized: true,
          alreadyAnnounced: false,
        ),
        true,
      );
    });
  });

  group('SettingsScreen System Shell Bridge UI', () {
    testWidgets('displays Shizuku status cleanly without badges or pulse dots', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ShellExecutorService.channel, (call) async {
        if (call.method == 'getStatus') {
          return {
            'available': true,
            'running': true,
            'authorized': true,
            'backend': 'shizuku',
            'installedBackend': 'shizuku',
            'uid': 2000,
            'modeLabel': 'Active (ADB UID 2000 via Shizuku)',
          };
        }
        return null;
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Shell Bridge'), findsOneWidget);
      expect(find.text('Active (ADB UID 2000 via Shizuku)'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byType(FluidPulseIndicator), findsNothing);
    });
  });

  group('ChatNotifier synthetic ReAct prompt filtering', () {
    test('accurately identifies synthetic ReAct prompts and strips them', () {
      const syntheticApproval =
          "User approved mobile action 'adb_shell'. Execution result:\n"
          "Shell command completed via shizuku (exit 0): Current Battery Service state: AC powered: true\n"
          "Please formulate a natural response to the user based on this outcome.";

      const syntheticRejection =
          "User declined/rejected the mobile action 'adb_shell'. "
          "Please acknowledge the cancellation and ask how you can help next.";

      const syntheticObservation =
          "Observation from mobile execution:\n"
          "[ACTION: get_device_info RESULT: {\"os\": \"Android 14\"}]\n"
          "Please provide a helpful, natural response to the user based on these device observation results.";

      const syntheticNudge =
          "You concluded your reasoning in <think>, but did not provide your response or mobile action block yet. "
          "Please directly provide your final response or output the ```mobile_action block now.";

      expect(ChatNotifier.isSyntheticReActPrompt(syntheticApproval), isTrue);
      expect(ChatNotifier.isSyntheticReActPrompt(syntheticRejection), isTrue);
      expect(ChatNotifier.isSyntheticReActPrompt(syntheticObservation), isTrue);
      expect(ChatNotifier.isSyntheticReActPrompt(syntheticNudge), isTrue);
    });

    test('retains genuine user messages and capability-augmented user messages', () {
      const normalUserMsg = 'cek status baterai hp gue';
      const augmentedUserMsg = 'cek status baterai hp gue\n\n[PRIVILEGED SHELL CAPABILITY]\nCRITICAL RULES...';
      const normalQuestion = 'tolong jelaskan cara kerja shizuku';

      expect(ChatNotifier.isSyntheticReActPrompt(normalUserMsg), isFalse);
      expect(ChatNotifier.isSyntheticReActPrompt(augmentedUserMsg), isFalse);
      expect(ChatNotifier.isSyntheticReActPrompt(normalQuestion), isFalse);
    });
  });
}
