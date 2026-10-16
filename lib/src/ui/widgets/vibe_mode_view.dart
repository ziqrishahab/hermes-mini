import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../services/hermes_connection.dart';
import '../../theme.dart';

class VibeFileItem {
  final String id;
  final String name;
  final String path;
  final String language;
  final String content;
  final String? toolOrigin;

  const VibeFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.language,
    required this.content,
    this.toolOrigin,
  });
}

class VibeActivityItem {
  final String title;
  final String type; // 'command', 'tool', 'reasoning', 'error'
  final String? detail;
  final String? output;
  final DateTime timestamp;
  final bool isSuccess;

  const VibeActivityItem({
    required this.title,
    required this.type,
    this.detail,
    this.output,
    required this.timestamp,
    this.isSuccess = true,
  });
}

class VibeModeView extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final void Function(String command)? onQuickPrompt;
  final String? activeCwd;
  final HermesConnection? connection;

  const VibeModeView({
    super.key,
    required this.messages,
    required this.isGenerating,
    this.onQuickPrompt,
    this.activeCwd,
    this.connection,
  });

  @override
  State<VibeModeView> createState() => _VibeModeViewState();
}

class _VibeModeViewState extends State<VibeModeView> {
  int _selectedFileIndex = 0;
  bool _isTerminalExpanded = false;
  bool _copied = false;

  List<VibeFileItem> _files = [];
  List<VibeActivityItem> _activities = [];
  final Set<int> _expandedActivityIndices = {};
  List<Map<String, dynamic>> _remoteFiles = [];
  bool _loadingRemoteFiles = false;
  String? _loadingFilePath;
  String? _resolvedCwd;
  String? _currentExplorerSubpath;
  DateTime? _clearedTerminalTimestamp;

  bool _isActivityCleared(DateTime timestamp) {
    if (_clearedTerminalTimestamp == null) return false;
    return !timestamp.isAfter(_clearedTerminalTimestamp!);
  }

  @override
  void initState() {
    super.initState();
    _parseMessages();
    _fetchWorkspaceFiles();
  }

  @override
  void didUpdateWidget(VibeModeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isNewSession = widget.messages.isNotEmpty &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.first.id != oldWidget.messages.first.id;
    if (isNewSession || widget.messages.isEmpty) {
      _clearedTerminalTimestamp = null;
    }
    final messagesChanged = widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty && oldWidget.messages.isNotEmpty &&
            (widget.messages.last.content != oldWidget.messages.last.content ||
             widget.messages.last.isStreaming != oldWidget.messages.last.isStreaming ||
             widget.messages.last.toolOutput != oldWidget.messages.last.toolOutput));
    if (messagesChanged || widget.isGenerating != oldWidget.isGenerating) {
      _parseMessages();
    }
    if (widget.activeCwd != oldWidget.activeCwd || widget.connection != oldWidget.connection) {
      _fetchWorkspaceFiles();
    }
  }

  bool _isItemDir(Map<String, dynamic> item, String name) {
    if (item['isDir'] == true ||
        item['is_dir'] == true ||
        item['is_dir'] == 1 ||
        item['is_directory'] == true ||
        item['isDirectory'] == true) {
      return true;
    }
    final type = item['type']?.toString().toLowerCase();
    if (type == 'dir' || type == 'directory' || type == 'folder' || type == 'd') {
      return true;
    }

    final lower = name.toLowerCase();
    if (lower == '.config' ||
        lower == '.claude' ||
        lower == '.claw' ||
        lower == '.cline' ||
        lower == '.codex' ||
        lower == '.copilot' ||
        lower == '.dbus-keyrings' ||
        lower == 'electron-gyp' ||
        lower == '.git' ||
        lower == '.github' ||
        lower == '.vscode' ||
        lower == '.dart_tool' ||
        lower == '.idea' ||
        lower == 'lib' ||
        lower == 'src' ||
        lower == 'test' ||
        lower == 'bin' ||
        lower == 'build' ||
        lower == 'assets' ||
        lower == 'android' ||
        lower == 'ios' ||
        lower == 'web' ||
        lower == 'windows' ||
        lower == 'linux' ||
        lower == 'macos') {
      return true;
    }

    if (!name.contains('.')) return true;

    final parts = name.split('.');
    if (name.startsWith('.') && parts.length == 2) {
      const knownFileExts = {
        'json', 'yaml', 'yml', 'dart', 'py', 'js', 'ts', 'md', 'txt', 'html', 'css', 'sh', 'lock', 'env', 'gitignore', 'conf', 'cfg', 'ini', 'xml'
      };
      if (!knownFileExts.contains(parts[1].toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  String? _getParentPath(String path) {
    final sep = path.contains('\\') ? '\\' : '/';
    final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    if (parts.length <= 1) return null;
    parts.removeLast();
    if (path.startsWith(sep)) {
      return '$sep${parts.join(sep)}';
    }
    if (path.length >= 2 && path[1] == ':') {
      if (parts.length == 1) return '${parts.first}\\';
      return parts.join('\\');
    }
    return parts.join(sep);
  }

  Future<void> _fetchWorkspaceFiles({String? subpath}) async {
    if (widget.connection == null) return;
    setState(() => _loadingRemoteFiles = true);
    try {
      final cwd = widget.activeCwd ?? await widget.connection!.getActiveWorkspaceCwd();
      if (cwd != null && cwd.isNotEmpty && mounted) {
        setState(() => _resolvedCwd = cwd);
      }
      final items = await widget.connection!.listWorkspaceFiles(subpath: subpath);
      if (mounted) {
        setState(() {
          _currentExplorerSubpath = subpath;
          _remoteFiles = items;
          _loadingRemoteFiles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRemoteFiles = false);
    }
  }

  Future<void> _openRemoteFile(String path, BuildContext modalCtx) async {
    final fileName = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
    final existingIdx = _files.indexWhere((f) => f.path == path || f.name == fileName);
    if (existingIdx != -1) {
      setState(() => _selectedFileIndex = existingIdx);
      if (Navigator.canPop(modalCtx)) Navigator.pop(modalCtx);
      return;
    }

    if (widget.connection == null) return;

    setState(() => _loadingFilePath = path);
    try {
      final content = await widget.connection!.readWorkspaceFile(path);
      if (content != null && content.isNotEmpty && mounted) {
        final newFile = VibeFileItem(
          id: 'remote_$path',
          name: fileName,
          path: path,
          language: _detectLanguage(fileName),
          content: content,
          toolOrigin: 'Remote Workspace',
        );

        setState(() {
          _files.insert(0, newFile);
          _selectedFileIndex = 0;
          _loadingFilePath = null;
        });

        HapticFeedback.lightImpact();
        if (modalCtx.mounted && Navigator.canPop(modalCtx)) Navigator.pop(modalCtx);
        return;
      }
    } catch (e) {
      debugPrint("Error opening remote file: $e");
    }

    // If reading failed because it is a directory, navigate into it smoothly
    if (_isItemDir({'path': path}, fileName)) {
      if (mounted) {
        setState(() => _loadingFilePath = null);
        await _fetchWorkspaceFiles(subpath: path);
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingFilePath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to read file: $path"),
          backgroundColor: HermesTokens.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _parseMessages() {
    final filesMap = <String, VibeFileItem>{};
    final activities = <VibeActivityItem>[];

    for (int i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];

      // 1. Tool Call Message or Explicit Tool Properties
      if (msg.toolName != null && msg.toolName!.isNotEmpty) {
        final out = (msg.toolOutput != null && msg.toolOutput!.isNotEmpty)
            ? msg.toolOutput!
            : (msg.role == MessageRole.tool ? msg.content : '');
        _processToolCall(
          name: msg.toolName!,
          input: msg.toolInput ?? '',
          output: out,
          status: msg.toolStatus,
          timestamp: msg.timestamp,
          sourceIndex: i,
          filesMap: filesMap,
          activities: activities,
        );
      } else if (msg.role == MessageRole.tool) {
        // Fallback for standalone tool role message without toolName
        if (!_isActivityCleared(msg.timestamp)) {
          final toolName = msg.toolName ?? 'tool';
          final cleanOut = _cleanToolOutput(msg.content);
          activities.add(VibeActivityItem(
            title: toolName,
            type: 'tool',
            detail: null,
            output: cleanOut.isNotEmpty ? cleanOut : null,
            timestamp: msg.timestamp,
            isSuccess: !(msg.toolStatus == 'error'),
          ));
        }
      }

      // 3. Embedded XML Tool Calls in message content (<tool_call...> or <tool...>)
      if (msg.content.contains('<tool') || msg.content.contains('<tool_call')) {
        final toolRegex = RegExp(
          r'<(?:tool_call|tool)(?:\s+name="([^"]+)")?>([\s\S]*?)(?:<\/(?:tool_call|tool)>|$)',
          caseSensitive: false,
        );
        for (final m in toolRegex.allMatches(msg.content)) {
          final nameAttr = m.group(1);
          final body = m.group(2)?.trim() ?? '';
          final nameMatch = RegExp(r'<name>([^<]+)<\/name>').firstMatch(body);
          final rawToolName = nameAttr ?? nameMatch?.group(1)?.trim() ?? 'tool';
          final argMatch = RegExp(r'<arguments>([\s\S]*?)<\/arguments>').firstMatch(body);
          final outMatch = RegExp(r'<(?:output|result)>([\s\S]*?)<\/(?:output|result)>').firstMatch(body);
          final toolInput = argMatch?.group(1)?.trim() ?? (nameAttr != null ? body : '');
          final toolOutput = outMatch?.group(1)?.trim() ?? '';

          _processToolCall(
            name: rawToolName,
            input: toolInput,
            output: toolOutput,
            status: 'completed',
            timestamp: msg.timestamp,
            sourceIndex: i,
            filesMap: filesMap,
            activities: activities,
          );
        }
      }

      // 4. Thought / Reasoning Process (<think>...</think> or <thinking>...</thinking>)
      if (!_isActivityCleared(msg.timestamp) && (msg.content.contains('<think') || msg.content.contains('<thinking'))) {
        final thinkRegex = RegExp(
          r'<(?:think|thinking)>([\s\S]*?)(?:<\/(?:think|thinking)>|$)',
          caseSensitive: false,
        );
        for (final m in thinkRegex.allMatches(msg.content)) {
          String thought = m.group(1)?.trim() ?? '';
          if (thought.isNotEmpty) {
            final tickerRegex = RegExp(r'[(\[（][^)\]）\n]*?[)\]）]\s*(?:contemplating|reasoning|brainstorming|reflecting|ruminating|cogitating|formulating|thinking)\.{3}\s*', caseSensitive: false);
            thought = thought.replaceAll(tickerRegex, '').trim();
            if (thought.isNotEmpty) {
              final firstLine = thought.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Reasoning');
              final preview = firstLine.length > 80 ? '${firstLine.substring(0, 80)}...' : firstLine;
              activities.add(VibeActivityItem(
                title: 'Thought Process',
                type: 'thought',
                detail: preview,
                output: thought,
                timestamp: msg.timestamp,
                isSuccess: true,
              ));
            }
          }
        }
      }

      // 5. Parse Markdown Code Blocks in Assistant Messages
      if (msg.role == MessageRole.assistant) {
        final codeRegex = RegExp(r'```(\w+)?\r?\n([\s\S]*?)```', multiLine: true);
        final matches = codeRegex.allMatches(msg.content);

        int snippetIdx = 1;
        for (final m in matches) {
          final lang = (m.group(1) ?? 'dart').trim().toLowerCase();
          final code = (m.group(2) ?? '').trim();

          if (code.isEmpty) continue;

          // If it's a bash/shell command block, add to terminal activity
          if (lang == 'bash' || lang == 'sh' || lang == 'shell' || lang == 'cmd' || lang == 'powershell' || lang == 'zsh') {
            if (!_isActivityCleared(msg.timestamp)) {
              final lines = code.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
              for (final cmdLine in lines) {
                activities.add(VibeActivityItem(
                  title: 'terminal',
                  type: 'command',
                  detail: cmdLine.startsWith('\$') ? cmdLine : '\$ $cmdLine',
                  output: null,
                  timestamp: msg.timestamp,
                  isSuccess: true,
                ));
              }
            }
            continue;
          }

          String detectedName = _extractFileNameFromCode(code, lang, snippetIdx);
          String filePath = detectedName;

          final key = 'md_${detectedName}_$snippetIdx';
          filesMap[key] = VibeFileItem(
            id: key,
            name: detectedName,
            path: filePath,
            language: lang.isEmpty ? 'dart' : lang,
            content: code,
            toolOrigin: 'Hermes Assistant',
          );
          snippetIdx++;
        }
      }
    }

    // 6. Active Live Running Indicator when isGenerating is true
    if (widget.isGenerating) {
      activities.add(VibeActivityItem(
        title: 'Hermes Agent Active',
        type: 'running',
        detail: 'Executing instructions and analyzing workspace...',
        output: null,
        timestamp: DateTime.now(),
        isSuccess: true,
      ));
    }

    final parsedFiles = filesMap.values.toList();
    // Preserve remote files that were opened manually by the user
    final remoteFiles = _files.where((f) => f.id.startsWith('remote_')).toList();
    for (final rf in remoteFiles) {
      if (!parsedFiles.any((pf) => pf.path == rf.path || pf.id == rf.id)) {
        parsedFiles.add(rf);
      }
    }

    setState(() {
      _files = parsedFiles;
      _activities = activities.reversed.toList();
      if (_selectedFileIndex >= _files.length) {
        _selectedFileIndex = _files.isNotEmpty ? _files.length - 1 : 0;
      }
    });
  }

  String _cleanToolInput(String name, String input) {
    if (input.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map) {
        if (decoded.containsKey('CommandLine') && decoded['CommandLine'] != null) {
          final cmd = decoded['CommandLine'].toString().trim();
          return cmd.startsWith('\$') ? cmd : '\$ $cmd';
        }
        if (decoded.containsKey('command') && decoded['command'] != null) {
          final cmd = decoded['command'].toString().trim();
          return cmd.startsWith('\$') ? cmd : '\$ $cmd';
        }
        if (decoded.containsKey('cmd') && decoded['cmd'] != null) {
          final cmd = decoded['cmd'].toString().trim();
          return cmd.startsWith('\$') ? cmd : '\$ $cmd';
        }
        if (decoded.containsKey('TargetFile') && decoded['TargetFile'] != null) {
          return decoded['TargetFile'].toString();
        }
        if (decoded.containsKey('path') && decoded['path'] != null) {
          return decoded['path'].toString();
        }
        if (decoded.containsKey('query') && decoded['query'] != null) {
          return decoded['query'].toString();
        }
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      }
    } catch (_) {}
    return input.trim();
  }

  String _cleanToolOutput(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        if (decoded.containsKey('output') && decoded['output'] != null) {
          return decoded['output'].toString();
        }
        if (decoded.containsKey('result') && decoded['result'] != null) {
          return decoded['result'].toString();
        }
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      } else if (decoded is List) {
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      }
    } catch (_) {}
    return raw;
  }

  void _processToolCall({
    required String name,
    required String input,
    required String output,
    String? status,
    required DateTime timestamp,
    required int sourceIndex,
    required Map<String, VibeFileItem> filesMap,
    required List<VibeActivityItem> activities,
  }) {
    if (_isActivityCleared(timestamp)) return;

    final lower = name.toLowerCase();
    final isSuccess = !(status?.toLowerCase() == 'error');

    if (lower.contains('write') || lower.contains('edit') || lower.contains('replace') || lower.contains('create')) {
      String? extractedPath;
      String? extractedCode;

      try {
        final decoded = jsonDecode(input);
        if (decoded is Map) {
          extractedPath = decoded['TargetFile']?.toString() ??
              decoded['path']?.toString() ??
              decoded['file']?.toString() ??
              decoded['filename']?.toString();

          extractedCode = decoded['CodeContent']?.toString() ??
              decoded['ReplacementContent']?.toString() ??
              decoded['content']?.toString();
        }
      } catch (_) {
        final fileMatch = RegExp(r'''["']?(?:TargetFile|path|file)["']?\s*:\s*["']([^"']+)["']''').firstMatch(input);
        if (fileMatch != null) extractedPath = fileMatch.group(1);
      }

      if (extractedPath != null && extractedCode != null && extractedCode.trim().isNotEmpty) {
        final fileName = extractedPath.split(RegExp(r'[\\/]')).last;
        final lang = _detectLanguage(fileName);
        filesMap[extractedPath] = VibeFileItem(
          id: 'tool_${sourceIndex}_$fileName',
          name: fileName,
          path: extractedPath,
          language: lang,
          content: extractedCode,
          toolOrigin: name,
        );
      }

      final cleanDetail = extractedPath ?? _cleanToolInput(name, input);
      final cleanOut = _cleanToolOutput(output);

      final existingIdx = activities.indexWhere((a) =>
          a.title == name &&
          (cleanDetail.isEmpty || a.detail == cleanDetail) &&
          (a.timestamp.difference(timestamp).abs().inSeconds < 10));

      if (existingIdx != -1) {
        final existing = activities[existingIdx];
        activities[existingIdx] = VibeActivityItem(
          title: existing.title,
          type: existing.type,
          detail: existing.detail ?? (cleanDetail.isNotEmpty ? cleanDetail : null),
          output: cleanOut.isNotEmpty ? cleanOut : existing.output,
          timestamp: existing.timestamp,
          isSuccess: isSuccess && existing.isSuccess,
        );
        return;
      }

      activities.add(VibeActivityItem(
        title: name,
        type: 'file',
        detail: cleanDetail.isNotEmpty ? cleanDetail : null,
        output: cleanOut.isNotEmpty ? cleanOut : null,
        timestamp: timestamp,
        isSuccess: isSuccess,
      ));
    } else if (lower.contains('run_command') || lower.contains('bash') || lower.contains('terminal') || lower.contains('exec') || lower.contains('sh')) {
      final cleanCmd = _cleanToolInput(name, input);
      final cleanOut = _cleanToolOutput(output);

      final existingIdx = activities.indexWhere((a) =>
          (a.title == name || a.type == 'command') &&
          (cleanCmd.isEmpty || a.detail == cleanCmd) &&
          (a.timestamp.difference(timestamp).abs().inSeconds < 10));

      if (existingIdx != -1) {
        final existing = activities[existingIdx];
        activities[existingIdx] = VibeActivityItem(
          title: existing.title,
          type: 'command',
          detail: existing.detail ?? (cleanCmd.isNotEmpty ? cleanCmd : null),
          output: cleanOut.isNotEmpty ? cleanOut : existing.output,
          timestamp: existing.timestamp,
          isSuccess: isSuccess && existing.isSuccess,
        );
        return;
      }

      activities.add(VibeActivityItem(
        title: name,
        type: 'command',
        detail: cleanCmd.isNotEmpty ? cleanCmd : null,
        output: cleanOut.isNotEmpty ? cleanOut : null,
        timestamp: timestamp,
        isSuccess: isSuccess,
      ));
    } else {
      final cleanInput = _cleanToolInput(name, input);
      final cleanOut = _cleanToolOutput(output);

      final existingIdx = activities.indexWhere((a) =>
          a.title == name &&
          (cleanInput.isEmpty || a.detail == cleanInput) &&
          (a.timestamp.difference(timestamp).abs().inSeconds < 10));

      if (existingIdx != -1) {
        final existing = activities[existingIdx];
        activities[existingIdx] = VibeActivityItem(
          title: existing.title,
          type: existing.type,
          detail: existing.detail ?? (cleanInput.isNotEmpty ? cleanInput : null),
          output: cleanOut.isNotEmpty ? cleanOut : existing.output,
          timestamp: existing.timestamp,
          isSuccess: isSuccess && existing.isSuccess,
        );
        return;
      }

      activities.add(VibeActivityItem(
        title: name,
        type: 'tool',
        detail: cleanInput.isNotEmpty ? cleanInput : null,
        output: cleanOut.isNotEmpty ? cleanOut : null,
        timestamp: timestamp,
        isSuccess: isSuccess,
      ));
    }
  }

  String _extractFileNameFromCode(String code, String lang, int fallbackIdx) {
    final firstLines = code.split('\n').take(3).join('\n');
    final match = RegExp(r'(?://|/\*|#|<!--)\s*(?:file:?\s*)?([a-zA-Z0-9_\-./\\]+\.[a-zA-Z0-9]+)', caseSensitive: false)
        .firstMatch(firstLines);

    if (match != null) {
      final raw = match.group(1)!;
      return raw.split(RegExp(r'[\\/]')).last;
    }

    final ext = _languageExtension(lang);
    return 'snippet_$fallbackIdx.$ext';
  }

  String _detectLanguage(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'py':
        return 'python';
      case 'js':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'md':
        return 'markdown';
      case 'sql':
        return 'sql';
      default:
        return 'plaintext';
    }
  }

  String _languageExtension(String lang) {
    switch (lang.toLowerCase()) {
      case 'dart':
        return 'dart';
      case 'python':
      case 'py':
        return 'py';
      case 'javascript':
      case 'js':
        return 'js';
      case 'typescript':
      case 'ts':
        return 'ts';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'bash':
      case 'sh':
        return 'sh';
      default:
        return 'txt';
    }
  }

  IconData _getFileIcon(String lang) {
    switch (lang.toLowerCase()) {
      case 'dart':
        return Icons.flutter_dash;
      case 'python':
        return Icons.terminal_rounded;
      case 'javascript':
      case 'typescript':
        return Icons.javascript_rounded;
      case 'json':
      case 'yaml':
        return Icons.data_object_rounded;
      case 'html':
      case 'css':
        return Icons.web_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  void _copyActiveCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _copied = true);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = _files.isNotEmpty;
    final activeFile = hasFiles && _selectedFileIndex < _files.length
        ? _files[_selectedFileIndex]
        : null;

    return Container(
      color: HermesTokens.bgPrimary,
      child: Column(
        children: [
          // 1. Editor File Tabs Bar
          _buildTabBar(hasFiles),

          // 2. Editor Canvas / Empty State
          Expanded(
            child: activeFile != null
                ? _buildCodeCanvas(activeFile)
                : _buildEmptyWorkspaceState(),
          ),

          // 3. Collapsible Terminal & Activity Log Drawer
          _buildTerminalDrawer(),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool hasFiles) {
    final effectiveCwd = _currentExplorerSubpath ?? widget.activeCwd ?? _resolvedCwd;
    final folderName = (effectiveCwd != null && effectiveCwd.isNotEmpty)
        ? effectiveCwd.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last
        : "Workspace";

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: NeumorphicDecoration.raised(
          radius: 19,
          distance: 1.5,
          blur: 3,
          color: HermesTokens.bgSecondary,
        ),
        child: Row(
          children: [
            // Single Workspace Explorer Pill Button
            InkWell(
              onTap: () => _showDirectoryExplorer(context),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: NeumorphicDecoration.raised(
                  radius: 15,
                  distance: 1.2,
                  blur: 2.5,
                  color: HermesTokens.bgPrimary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 14,
                      color: HermesTokens.accentText,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 95),
                      child: Text(
                        folderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: HermesTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 18,
              color: HermesTokens.border,
            ),
            const SizedBox(width: 6),
            // Horizontal tabs
            Expanded(
              child: hasFiles
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _files.length,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemBuilder: (ctx, idx) {
                        final file = _files[idx];
                        final isSelected = idx == _selectedFileIndex;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFileIndex = idx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: isSelected
                                ? NeumorphicDecoration.recessed(radius: 12)
                                : BoxDecoration(
                                    color: HermesTokens.bgPrimary.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: HermesTokens.border.withValues(alpha: 0.5)),
                                  ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getFileIcon(file.language),
                                  size: 12,
                                  color: isSelected
                                      ? HermesTokens.accentText
                                      : HermesTokens.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  file.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? HermesTokens.textPrimary
                                        : HermesTokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        'No files opened yet',
                        style: TextStyle(fontSize: 10.5, color: HermesTokens.textMuted),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCanvas(VibeFileItem file) {
    final lines = file.content.split('\n');

    return Container(
      color: const Color(0xFF1E1E2E), // Modern IDE dark editor background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File Breadcrumbs & Actions Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              border: Border(
                bottom: BorderSide(color: Color(0xFF313244), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(file.language),
                        size: 15,
                        color: const Color(0xFF89B4FA),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFCDD6F4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Language Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF313244),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    file.language.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFA6ADC8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Lines count
                Text(
                  '${lines.length} lines',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: const Color(0xFF6C7086),
                  ),
                ),
                const SizedBox(width: 10),
                // Copy Button
                GestureDetector(
                  onTap: () => _copyActiveCode(file.content),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _copied ? const Color(0xFF2E7D32) : const Color(0xFF313244),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code Text Area with Line Numbers
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line numbers gutter
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(lines.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              height: 1.5,
                              color: const Color(0xFF45475A),
                            ),
                          ),
                        );
                      }),
                    ),
                    // Syntax Highlighted Code
                    HighlightView(
                      file.content,
                      language: file.language.isEmpty ? 'plaintext' : file.language,
                      theme: atomOneDarkTheme,
                      padding: EdgeInsets.zero,
                      textStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkspaceState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: NeumorphicDecoration.raised(radius: 14),
              child: const Icon(
                Icons.code_rounded,
                size: 22,
                color: HermesTokens.accentText,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vibe Code Canvas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HermesTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No files open yet. Tap the workspace folder on the left or ask Hermes to write code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: HermesTokens.textMuted,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _emptyStateActionChip(
                  label: 'Workspace Files',
                  icon: Icons.folder_open_rounded,
                  prompt: 'List project files in the current workspace',
                ),
                _emptyStateActionChip(
                  label: 'Generate Widget',
                  icon: Icons.widgets_outlined,
                  prompt: 'Create a responsive modern Flutter card widget with clean neumorphic styling',
                ),
                _emptyStateActionChip(
                  label: 'Review Architecture',
                  icon: Icons.architecture_rounded,
                  prompt: 'Analyze current workspace structure and propose improvements',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStateActionChip({
    required String label,
    required IconData icon,
    required String prompt,
  }) {
    return InkWell(
      onTap: () {
        if (widget.onQuickPrompt != null) {
          widget.onQuickPrompt!(prompt);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: HermesTokens.accentText),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HermesTokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalDrawer() {
    final activityCount = _activities.length;
    final isGenerating = widget.isGenerating;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: _isTerminalExpanded ? 260 : 42,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF11111B),
        border: Border(
          top: BorderSide(color: Color(0xFF313244), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drawer Header Bar
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isTerminalExpanded = !_isTerminalExpanded);
            },
            child: SizedBox(
              height: 41,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 16,
                    color: isGenerating ? const Color(0xFFFAB387) : const Color(0xFFA6E3A1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Terminal & Agent Activity',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFCDD6F4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF313244),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$activityCount events',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFA6ADC8),
                      ),
                    ),
                  ),
                  if (isGenerating) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAB387).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RUNNING',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFAB387),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_isTerminalExpanded && _activities.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _clearedTerminalTimestamp = DateTime.now();
                          _activities.clear();
                          _expandedActivityIndices.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF313244),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFBAC2DE),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    _isTerminalExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: const Color(0xFFA6ADC8),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),

          // Expanded Terminal Content
          if (_isTerminalExpanded)
            Expanded(
              child: Container(
                color: const Color(0xFF0F0F17),
                child: _activities.isEmpty
                    ? Center(
                        child: Text(
                          'No shell commands or tool activity recorded yet',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF6C7086),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _activities.length,
                        itemBuilder: (ctx, idx) {
                          final item = _activities[idx];
                          final isCmd = item.type == 'command';
                          final isThought = item.type == 'thought';
                          final isRunning = item.type == 'running';

                          String tagText = 'TOOL';
                          Color tagBg = const Color(0xFF45475A);
                          Color tagFg = Colors.white;

                          if (isCmd) {
                            tagText = 'SH';
                            tagBg = const Color(0xFF1E66F5);
                          } else if (item.type == 'file') {
                            tagText = 'FILE';
                            tagBg = const Color(0xFF04A5E5);
                            tagFg = const Color(0xFF11111B);
                          } else if (item.type == 'prompt') {
                            tagText = 'AI';
                            tagBg = const Color(0xFFCBA6F7);
                            tagFg = const Color(0xFF11111B);
                          } else if (item.type == 'info') {
                            tagText = 'INFO';
                            tagBg = const Color(0xFF89DCEB);
                            tagFg = const Color(0xFF11111B);
                          } else if (isThought) {
                            tagText = 'THINK';
                            tagBg = const Color(0xFFFAB387);
                            tagFg = const Color(0xFF11111B);
                          } else if (isRunning) {
                            tagText = 'LIVE';
                            tagBg = const Color(0xFFA6E3A1);
                            tagFg = const Color(0xFF11111B);
                          }

                          final isExpanded = _expandedActivityIndices.contains(idx);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tagBg,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        tagText,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: tagFg,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isRunning
                                              ? const Color(0xFFA6E3A1)
                                              : (item.isSuccess ? const Color(0xFFA6E3A1) : const Color(0xFFF38BA8)),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        color: const Color(0xFF585B70),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.detail != null &&
                                    item.detail!.isNotEmpty &&
                                    item.detail != item.title)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, left: 4),
                                    child: Text(
                                      item.detail!,
                                      maxLines: isExpanded ? null : 3,
                                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: item.detail!.startsWith('\$') ? FontWeight.w600 : FontWeight.w400,
                                        color: item.detail!.startsWith('\$') ? const Color(0xFF89B4FA) : const Color(0xFFBAC2DE),
                                      ),
                                    ),
                                  ),
                                if (item.output != null && item.output!.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedActivityIndices.remove(idx);
                                        } else {
                                          _expandedActivityIndices.add(idx);
                                        }
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 4, left: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF181825),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isExpanded ? const Color(0xFF89B4FA) : const Color(0xFF313244),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.output!,
                                            maxLines: isExpanded ? null : 6,
                                            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10,
                                              height: 1.4,
                                              color: const Color(0xFFBAC2DE),
                                            ),
                                          ),
                                          if (item.output!.length > 120)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    isExpanded ? 'Collapse' : 'Tap to expand full output',
                                                    style: GoogleFonts.jetBrainsMono(
                                                      fontSize: 9,
                                                      color: const Color(0xFF6C7086),
                                                    ),
                                                  ),
                                                  Icon(
                                                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                    size: 13,
                                                    color: const Color(0xFF6C7086),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDirectoryExplorer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String filterQuery = '';
        String activeFilterTab = 'all'; // 'all', 'folders', 'files'

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final rootCwd = widget.activeCwd ?? _resolvedCwd ?? 'Active Workspace';
            final currentPath = _currentExplorerSubpath ?? rootCwd;

            // Gather candidate files
            final candidateFiles = <Map<String, dynamic>>[];

            // If at root of explorer, show open tabs first
            if (_currentExplorerSubpath == null) {
              for (final f in _files) {
                candidateFiles.add({
                  'name': f.name,
                  'path': f.path,
                  'isDir': false,
                  'source': f.toolOrigin ?? 'Active Tab',
                  'isOpen': true,
                });
              }
            }

            // Remote files
            for (final rf in _remoteFiles) {
              final path = rf['path']?.toString() ?? rf['name']?.toString() ?? '';
              final name = rf['name']?.toString() ?? path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).last;
              final isDir = _isItemDir(rf, name);

              if (path.isNotEmpty && !candidateFiles.any((c) => c['path'] == path)) {
                candidateFiles.add({
                  'name': name,
                  'path': path,
                  'isDir': isDir,
                  'source': 'Filesystem',
                  'isOpen': _files.any((f) => f.path == path || f.name == name),
                });
              }
            }

            // Filter by search and tabs
            final filtered = candidateFiles.where((c) {
              final name = c['name'].toString().toLowerCase();
              final path = c['path'].toString().toLowerCase();
              final q = filterQuery.toLowerCase().trim();

              if (q.isNotEmpty && !name.contains(q) && !path.contains(q)) {
                return false;
              }

              final isDir = c['isDir'] == true;
              if (activeFilterTab == 'folders' && !isDir) return false;
              if (activeFilterTab == 'files' && isDir) return false;

              return true;
            }).toList();

            // Sort: folders first, then alphabetical
            filtered.sort((a, b) {
              final aIsDir = a['isDir'] == true;
              final bIsDir = b['isDir'] == true;
              if (aIsDir && !bIsDir) return -1;
              if (!aIsDir && bIsDir) return 1;
              return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
            });

            final folderCount = candidateFiles.where((c) => c['isDir'] == true).length;
            final fileCount = candidateFiles.where((c) => c['isDir'] != true).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: HermesTokens.bgElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HermesTokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Explorer Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                          child: const Icon(Icons.folder_copy_rounded, size: 20, color: HermesTokens.accentText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Workspace Explorer",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: HermesTokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: HermesTokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: NeumorphicDecoration.raised(radius: 10, distance: 1.5, blur: 3),
                          child: IconButton(
                            tooltip: "Refresh workspace tree",
                            padding: EdgeInsets.zero,
                            icon: _loadingRemoteFiles
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18, color: HermesTokens.textSecondary),
                            onPressed: _loadingRemoteFiles
                                ? null
                                : () async {
                                    await _fetchWorkspaceFiles(subpath: _currentExplorerSubpath);
                                    setModalState(() {});
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: NeumorphicDecoration.raised(radius: 10, distance: 1.5, blur: 3),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close_rounded, size: 18, color: HermesTokens.textMuted),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Breadcrumb / Back button if inside subfolder
                  if (_currentExplorerSubpath != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: NeumorphicDecoration.recessed(radius: 10),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final parent = _getParentPath(_currentExplorerSubpath!);
                                setModalState(() => _currentExplorerSubpath = parent);
                                await _fetchWorkspaceFiles(subpath: parent);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: NeumorphicDecoration.raised(radius: 8, distance: 1, blur: 2),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_upward_rounded, size: 13, color: HermesTokens.accentText),
                                    SizedBox(width: 4),
                                    Text("Up to parent", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.accentText)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentExplorerSubpath!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: HermesTokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        style: const TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Search files or folders...",
                          hintStyle: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                          icon: const Icon(Icons.search_rounded, size: 18, color: HermesTokens.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: filterQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: HermesTokens.textMuted),
                                  onPressed: () {
                                    setModalState(() => filterQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            filterQuery = val;
                          });
                        },
                      ),
                    ),
                  ),

                  // Filter Chips (All, Folders, Files)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        _explorerFilterChip(
                          label: "All (${candidateFiles.length})",
                          isSelected: activeFilterTab == 'all',
                          onTap: () => setModalState(() => activeFilterTab = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _explorerFilterChip(
                          label: "Folders ($folderCount)",
                          isSelected: activeFilterTab == 'folders',
                          onTap: () => setModalState(() => activeFilterTab = 'folders'),
                        ),
                        const SizedBox(width: 6),
                        _explorerFilterChip(
                          label: "Files ($fileCount)",
                          isSelected: activeFilterTab == 'files',
                          onTap: () => setModalState(() => activeFilterTab = 'files'),
                        ),
                      ],
                    ),
                  ),

                  // File and Directory List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: NeumorphicDecoration.raised(radius: 16),
                                    child: const Icon(Icons.folder_off_outlined, size: 24, color: HermesTokens.textMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    filterQuery.isNotEmpty
                                        ? "No matching items for \"$filterQuery\""
                                        : "No files found in this directory",
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_currentExplorerSubpath != null)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        setModalState(() => _currentExplorerSubpath = null);
                                        await _fetchWorkspaceFiles();
                                        setModalState(() {});
                                      },
                                      icon: const Icon(Icons.home_rounded, size: 15),
                                      label: const Text("Go to Root Workspace"),
                                    )
                                  else
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await _fetchWorkspaceFiles();
                                        setModalState(() {});
                                      },
                                      icon: const Icon(Icons.sync_rounded, size: 15),
                                      label: const Text("Scan Filesystem"),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              final isDir = item['isDir'] == true;
                              final name = item['name'].toString();
                              final path = item['path'].toString();
                              final isOpen = item['isOpen'] == true;
                              final isLoadingThis = _loadingFilePath == path;
                              final lang = _detectLanguage(name);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    if (isDir) {
                                      // Drill down into directory!
                                      setModalState(() => _currentExplorerSubpath = path);
                                      await _fetchWorkspaceFiles(subpath: path);
                                      setModalState(() {});
                                    } else {
                                      // Open file in editor!
                                      _openRemoteFile(path, modalCtx);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: NeumorphicDecoration.raised(
                                      radius: 12,
                                      distance: 1.2,
                                      blur: 2.5,
                                      color: HermesTokens.bgPrimary,
                                    ),
                                    child: Row(
                                      children: [
                                        // Leading Icon Box
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isDir
                                                ? const Color(0xFF89B4FA).withValues(alpha: 0.15)
                                                : HermesTokens.accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isDir ? Icons.folder_rounded : _getFileIcon(lang),
                                            size: 18,
                                            color: isDir ? const Color(0xFF89B4FA) : HermesTokens.accentText,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Title & Monospace Subtitle
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: isDir ? FontWeight.w700 : FontWeight.w600,
                                                        color: HermesTokens.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  if (isDir)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        "DIR",
                                                        style: TextStyle(
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF89B4FA),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                path,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 9.5,
                                                  color: HermesTokens.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Trailing
                                        if (isLoadingThis)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                                          )
                                        else if (isOpen)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: HermesTokens.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              "OPEN",
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: HermesTokens.accentText,
                                              ),
                                            ),
                                          )
                                        else if (isDir)
                                          const Icon(Icons.chevron_right_rounded, size: 18, color: HermesTokens.textMuted)
                                        else
                                          const Icon(Icons.file_open_outlined, size: 16, color: HermesTokens.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _explorerFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: isSelected
            ? NeumorphicDecoration.recessed(radius: 8)
            : BoxDecoration(
                color: HermesTokens.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HermesTokens.border.withValues(alpha: 0.5)),
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? HermesTokens.accentText : HermesTokens.textMuted,
          ),
        ),
      ),
    );
  }
}
