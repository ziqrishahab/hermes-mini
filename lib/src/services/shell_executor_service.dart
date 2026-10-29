import 'dart:async';
import 'package:flutter/services.dart';

class ShellPrivilegeStatus {
  final bool available;
  final bool running;
  final bool authorized;
  final String backend;
  final String installedBackend;
  final int uid;
  final String modeLabel;

  const ShellPrivilegeStatus({
    required this.available,
    required this.running,
    required this.authorized,
    required this.backend,
    required this.installedBackend,
    required this.uid,
    required this.modeLabel,
  });

  const ShellPrivilegeStatus.inactive()
      : available = false,
        running = false,
        authorized = false,
        backend = 'none',
        installedBackend = 'none',
        uid = -1,
        modeLabel = 'Inactive (Requires Shizuku Next)';

  factory ShellPrivilegeStatus.fromMap(Map<dynamic, dynamic> map) {
    return ShellPrivilegeStatus(
      available: map['available'] == true,
      running: map['running'] == true,
      authorized: map['authorized'] == true,
      backend: (map['backend'] ?? 'none').toString(),
      installedBackend: (map['installedBackend'] ?? 'none').toString(),
      uid: (map['uid'] is num) ? (map['uid'] as num).toInt() : -1,
      modeLabel: (map['modeLabel'] ?? 'Inactive').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'available': available,
        'running': running,
        'authorized': authorized,
        'backend': backend,
        'installed_backend': installedBackend,
        'uid': uid,
        'mode_label': modeLabel,
      };
}

class ShellPermissionResult {
  final bool granted;
  final String backend;
  final String message;

  const ShellPermissionResult({
    required this.granted,
    required this.backend,
    required this.message,
  });
}

class ShellExecutionResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final String backend;
  final bool blocked;
  final String? blockReason;

  const ShellExecutionResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
    this.backend = 'none',
    this.blocked = false,
    this.blockReason,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'exit_code': exitCode,
        'backend': backend,
        'timed_out': timedOut,
        'blocked': blocked,
        if (blockReason != null) 'block_reason': blockReason,
        'stdout': stdout,
        'stderr': stderr,
      };
}

class ShellExecutorService {
  static const MethodChannel channel = MethodChannel('com.hermesmobile/shell');

  static final List<({RegExp pattern, String reason})> _blockedPatterns = [
    (
      pattern: RegExp(r':\s*\(\s*\)\s*\{'),
      reason: 'Fork bomb patterns are prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:^|[;&|`\s(])rm\s+[^\n;|&]*--no-preserve-root',
        caseSensitive: false,
      ),
      reason: 'Root filesystem deletion flags are prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:^|[;&|`\s(])rm\s+(?:-[a-zA-Z]*[rf][a-zA-Z]*\s+)+(?:/|/\*|~|\*|(?:\/sdcard|\/storage|\/system|\/data|\/vendor|\/boot|\/efs|\/proc|\/dev)(?:\/?\*?|\/)?(?:\s|$|[;&|]))',
        caseSensitive: false,
      ),
      reason: 'Recursive deletion of root, system, or shared storage directories is prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:^|[;&|`\s(])dd\s+[^\n;|&]*\bof=\/dev\/',
        caseSensitive: false,
      ),
      reason: 'Direct raw writes to block devices (/dev) are prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:^|[;&|`\s(])(?:mkfs(?:\.[a-z0-9]+)?|mke2fs|mkswap|fdisk|parted|sgdisk|wipefs|blkdiscard)\b',
        caseSensitive: false,
      ),
      reason: 'Filesystem formatting and partition modification utilities are prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:^|[;&|`\s(])reboot(?:\s+(?:bootloader|fastboot|recovery|edl|download))?\b',
        caseSensitive: false,
      ),
      reason: 'System reboot and bootloader mode transitions are prohibited.',
    ),
    (
      pattern: RegExp(
        r'(?:MASTER_CLEAR|--wipe_data|--wipe-data|wipe_data|recovery\s+--wipe|locksettings\s+clear)',
        caseSensitive: false,
      ),
      reason: 'Factory reset and lockscreen credential wipe commands are prohibited.',
    ),
    (
      pattern: RegExp(
        r'\bpm\s+(?:uninstall|disable|disable-user|clear|suspend)\b[^\n;|&]*(?:com\.hermesmobile\.hermes_mobile|moe\.shizuku\.privileged\.api)',
        caseSensitive: false,
      ),
      reason: 'Uninstalling, disabling, or clearing Hermes Mobile or Shizuku Next is prohibited.',
    ),
  ];

  /// Validates a shell command against local safety guardrails.
  /// Returns `null` when allowed, or a human-readable rejection reason when blocked.
  static String? validateCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return 'Shell command cannot be empty.';
    }
    for (final rule in _blockedPatterns) {
      if (rule.pattern.hasMatch(trimmed)) {
        return rule.reason;
      }
    }
    return null;
  }

  /// Queries whether Shizuku Next is installed, active, and authorized.
  static Future<ShellPrivilegeStatus> getStatus() async {
    try {
      final raw = await channel.invokeMethod<dynamic>('getStatus');
      if (raw is Map) {
        return ShellPrivilegeStatus.fromMap(raw);
      }
    } catch (_) {}
    return const ShellPrivilegeStatus.inactive();
  }

  /// Convenience check returning true only when the Shizuku Next shell backend is active and authorized.
  static Future<bool> isAuthorized() async {
    final status = await getStatus();
    return status.authorized;
  }

  /// Requests runtime permission from Shizuku Next.
  static Future<ShellPermissionResult> requestPermission() async {
    try {
      final raw = await channel.invokeMethod<dynamic>('requestPermission');
      if (raw is Map) {
        return ShellPermissionResult(
          granted: raw['granted'] == true,
          backend: (raw['backend'] ?? 'none').toString(),
          message: (raw['message'] ?? '').toString(),
        );
      }
    } catch (e) {
      return ShellPermissionResult(
        granted: false,
        backend: 'none',
        message: 'Permission request failed: $e',
      );
    }
    return const ShellPermissionResult(
      granted: false,
      backend: 'none',
      message: 'Privileged shell manager is unavailable.',
    );
  }

  /// Opens the installed Shizuku Next manager application.
  static Future<bool> openManagerApp() async {
    try {
      final ok = await channel.invokeMethod<bool>('openManagerApp');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Executes an Android shell command through Shizuku Next after validating safety rules.
  static Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final blockReason = validateCommand(command);
    if (blockReason != null) {
      return ShellExecutionResult(
        success: false,
        exitCode: 126,
        stdout: '',
        stderr: blockReason,
        blocked: true,
        blockReason: blockReason,
      );
    }

    try {
      final raw = await channel.invokeMethod<dynamic>('executeCommand', {
        'command': command.trim(),
        'timeoutMs': timeout.inMilliseconds,
      });
      if (raw is Map) {
        return ShellExecutionResult(
          success: raw['success'] == true,
          exitCode: (raw['exitCode'] is num) ? (raw['exitCode'] as num).toInt() : -1,
          stdout: (raw['stdout'] ?? '').toString(),
          stderr: (raw['stderr'] ?? '').toString(),
          timedOut: raw['timedOut'] == true,
          backend: (raw['backend'] ?? 'none').toString(),
        );
      }
      return const ShellExecutionResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: 'Invalid response from native shell bridge.',
      );
    } catch (e) {
      return ShellExecutionResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: 'Shell bridge error: $e',
      );
    }
  }
}
