import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../services/hermes_connection.dart';
import '../../theme.dart';

enum VibeDiffLineType { context, added, removed, header }

class VibeDiffLine {
  final VibeDiffLineType type;
  final int? oldLineNumber;
  final int? newLineNumber;
  final String content;

  const VibeDiffLine({
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
    required this.content,
  });
}

class VibeFileItem {
  final String id;
  final String name;
  final String path;
  final String language;
  final String content;
  final String? previousContent;
  final String? toolOrigin;
  final List<VibeDiffLine> diffLines;
  final int addedCount;
  final int removedCount;

  const VibeFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.language,
    required this.content,
    this.previousContent,
    this.toolOrigin,
    this.diffLines = const [],
    this.addedCount = 0,
    this.removedCount = 0,
  });

  bool get hasDiff => diffLines.isNotEmpty && (addedCount > 0 || removedCount > 0);
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
  final bool isActive;
  final void Function(String command)? onQuickPrompt;
  final String? activeCwd;
  final HermesConnection? connection;

  const VibeModeView({
    super.key,
    required this.messages,
    required this.isGenerating,
    this.isActive = true,
    this.onQuickPrompt,
    this.activeCwd,
    this.connection,
  });

  @override
  State<VibeModeView> createState() => _VibeModeViewState();
}

class _VibeModeViewState extends State<VibeModeView> {
  int _selectedFileIndex = 0;
  bool _showDiffView = true;
  bool _terminalExpanded = false;
  int? _expandedActivityIdx;
  bool _copied = false;

  List<VibeFileItem> _allFiles = [];
  final Set<String> _closedTabIds = {};
  final List<VibeFileItem> _manualReadFiles = [];
  List<VibeActivityItem> _activities = [];

  bool _needsReparse = true;
  DateTime _lastParseTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _throttleTimer;

  final ScrollController _codeVerticalScroll = ScrollController();
  final ScrollController _diffVerticalScroll = ScrollController();

  List<VibeFileItem> get _openFiles =>
      _allFiles.where((f) => !_closedTabIds.contains(f.id)).toList();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _parseMessages();
    } else {
      _needsReparse = true;
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _codeVerticalScroll.dispose();
    _diffVerticalScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VibeModeView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final messagesChanged =
        widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty &&
            oldWidget.messages.isNotEmpty &&
            (widget.messages.last.content != oldWidget.messages.last.content ||
                widget.messages.last.toolOutput != oldWidget.messages.last.toolOutput ||
                widget.messages.last.isStreaming != oldWidget.messages.last.isStreaming));

    final generationFinished = oldWidget.isGenerating && !widget.isGenerating;

    if (messagesChanged || generationFinished) {
      _needsReparse = true;
    }

    if (!widget.isActive) {
      return;
    }

    if (!oldWidget.isActive && widget.isActive && _needsReparse) {
      _runParseNow();
      return;
    }

    if (_needsReparse) {
      if (generationFinished || !widget.isGenerating) {
        _runParseNow();
      } else {
        final elapsed = DateTime.now().difference(_lastParseTime);
        if (elapsed >= const Duration(milliseconds: 280)) {
          _runParseNow();
        } else if (_throttleTimer == null || !_throttleTimer!.isActive) {
          _throttleTimer = Timer(
            const Duration(milliseconds: 280) - elapsed,
            () {
              if (mounted && widget.isActive && _needsReparse) {
                _runParseNow();
              }
            },
          );
        }
      }
    }
  }

  void _runParseNow() {
    _throttleTimer?.cancel();
    _lastParseTime = DateTime.now();
    _needsReparse = false;
    setState(() {
      _parseMessages();
    });
  }

  void _resetScrollPositions() {
    if (_codeVerticalScroll.hasClients) {
      _codeVerticalScroll.jumpTo(0);
    }
    if (_diffVerticalScroll.hasClients) {
      _diffVerticalScroll.jumpTo(0);
    }
  }

  void _selectFileTab(int index) {
    final open = _openFiles;
    if (index < 0 || index >= open.length) return;
    if (_selectedFileIndex == index) return;
    setState(() {
      _selectedFileIndex = index;
      final selected = open[index];
      _showDiffView = selected.hasDiff;
    });
    _resetScrollPositions();
  }

  void _closeFileTab(String id) {
    setState(() {
      _closedTabIds.add(id);
      final open = _openFiles;
      if (_selectedFileIndex >= open.length) {
        _selectedFileIndex = open.isEmpty ? 0 : open.length - 1;
      }
    });
    _resetScrollPositions();
  }

  void _reopenOrSelectFile(VibeFileItem item) {
    setState(() {
      _closedTabIds.remove(item.id);
      final open = _openFiles;
      final idx = open.indexWhere((f) => f.id == item.id);
      if (idx != -1) {
        _selectedFileIndex = idx;
        _showDiffView = open[idx].hasDiff;
      }
    });
    _resetScrollPositions();
  }

  void _parseMessages() {
    final filesMap = <String, VibeFileItem>{};
    final activitiesList = <VibeActivityItem>[];
    int globalSnippetIdx = 1;

    final toolRegex = RegExp(
      r'<(?:tool_call|tool_use|function_call|tool)\b[^>]*>([\s\S]*?)<\/(?:tool_call|tool_use|function_call|tool)>',
      caseSensitive: false,
    );
    final thinkRegex = RegExp(
      r'<(?:think|thinking)>([\s\S]*?)(?:<\/(?:think|thinking)>|$)',
      caseSensitive: false,
    );
    final codeRegex = RegExp(r'```([^\n`]*)\n([\s\S]*?)(?:```|$)');

    void upsertFile({
      required String key,
      required String name,
      required String path,
      required String language,
      required String content,
      String? explicitPreviousContent,
      String? rawDiffText,
      String? toolOrigin,
      bool isModificationOrCreation = false,
    }) {
      final existing = filesMap[key];
      final prevContent = explicitPreviousContent ?? existing?.content;

      List<VibeDiffLine> diffLines = const [];
      int added = 0;
      int removed = 0;

      if (rawDiffText != null && rawDiffText.trim().isNotEmpty) {
        final parsed = _parseUnifiedDiff(rawDiffText);
        diffLines = parsed.$1;
        added = parsed.$2;
        removed = parsed.$3;
      } else if (prevContent != null && prevContent != content) {
        final computed = _computeLineDiff(prevContent, content);
        diffLines = computed.$1;
        added = computed.$2;
        removed = computed.$3;
      } else if (isModificationOrCreation && prevContent == null) {
        final created = _computeCreatedDiff(content);
        diffLines = created.$1;
        added = created.$2;
        removed = 0;
      } else if (existing != null && existing.hasDiff && prevContent == content) {
        diffLines = existing.diffLines;
        added = existing.addedCount;
        removed = existing.removedCount;
      }

      filesMap[key] = VibeFileItem(
        id: key,
        name: name,
        path: path,
        language: language,
        content: content,
        previousContent: prevContent,
        toolOrigin: toolOrigin ?? existing?.toolOrigin,
        diffLines: diffLines,
        addedCount: added,
        removedCount: removed,
      );
    }

    for (int i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];

      if (msg.role == MessageRole.tool ||
          (msg.toolName != null && msg.toolName!.isNotEmpty)) {
        final tName = msg.toolName ?? 'tool_execution';
        final tInput = msg.toolInput ?? msg.content;
        final tOutput = msg.toolOutput;
        final isErr = msg.toolStatus == 'error';

        _extractFromTool(
          name: tName,
          inputRaw: tInput,
          outputRaw: tOutput,
          timestamp: msg.timestamp,
          isSuccess: !isErr,
          filesMap: filesMap,
          upsertFile: upsertFile,
          activitiesList: activitiesList,
        );
      }

      if (msg.role == MessageRole.reasoning) {
        if (msg.content.trim().isNotEmpty) {
          activitiesList.add(
            VibeActivityItem(
              title: 'Agent reasoning',
              type: 'reasoning',
              detail: _summarizeReasoning(msg.content),
              output: msg.content.trim(),
              timestamp: msg.timestamp,
            ),
          );
        }
        continue;
      }

      if (msg.role == MessageRole.assistant) {
        final raw = msg.content;

        for (final m in thinkRegex.allMatches(raw)) {
          final thought = m.group(1)?.trim() ?? '';
          if (thought.isNotEmpty) {
            activitiesList.add(
              VibeActivityItem(
                title: 'Thinking process',
                type: 'reasoning',
                detail: _summarizeReasoning(thought),
                output: thought,
                timestamp: msg.timestamp,
              ),
            );
          }
        }

        for (final m in toolRegex.allMatches(raw)) {
          final inner = m.group(1)?.trim() ?? '';
          if (inner.isNotEmpty) {
            String toolName = 'tool_call';
            String toolInput = inner;
            try {
              final decoded = jsonDecode(inner);
              if (decoded is Map) {
                toolName = (decoded['name'] ?? decoded['tool'] ?? 'tool_call')
                    .toString();
                if (decoded['arguments'] != null) {
                  toolInput = decoded['arguments'] is String
                      ? decoded['arguments'] as String
                      : const JsonEncoder.withIndent('  ')
                            .convert(decoded['arguments']);
                } else if (decoded['input'] != null) {
                  toolInput = decoded['input'] is String
                      ? decoded['input'] as String
                      : const JsonEncoder.withIndent('  ')
                            .convert(decoded['input']);
                }
              }
            } catch (_) {}

            _extractFromTool(
              name: toolName,
              inputRaw: toolInput,
              outputRaw: null,
              timestamp: msg.timestamp,
              isSuccess: true,
              filesMap: filesMap,
              upsertFile: upsertFile,
              activitiesList: activitiesList,
            );
          }
        }

        final cleanedForCode = raw
            .replaceAll(thinkRegex, '')
            .replaceAll(toolRegex, '');

        for (final m in codeRegex.allMatches(cleanedForCode)) {
          final header = (m.group(1) ?? '').trim();
          final codeBody = (m.group(2) ?? '').trimRight();
          if (codeBody.trim().isEmpty) continue;

          final parsedHeader = _parseCodeBlockHeader(
            header,
            codeBody,
            globalSnippetIdx,
            cleanedForCode.substring(0, m.start),
          );
          final lang = parsedHeader.$1;
          final filePath = parsedHeader.$2;
          final fileName = parsedHeader.$3;
          final isNamedFile = parsedHeader.$4;

          if (!isNamedFile) {
            globalSnippetIdx++;
          }

          if (lang == 'bash' ||
              lang == 'sh' ||
              lang == 'shell' ||
              lang == 'zsh' ||
              lang == 'powershell' ||
              lang == 'console') {
            if (!filePath.contains('.')) {
              final firstLine = codeBody.split('\n').first.trim();
              activitiesList.add(
                VibeActivityItem(
                  title: firstLine.length > 60
                      ? '${firstLine.substring(0, 60)}...'
                      : firstLine,
                  type: 'command',
                  detail: 'Shell snippet',
                  output: codeBody,
                  timestamp: msg.timestamp,
                ),
              );
              continue;
            }
          }

          final isUnifiedDiff =
              lang == 'diff' ||
              lang == 'patch' ||
              codeBody.startsWith('diff --git ') ||
              codeBody.startsWith('--- ') ||
              codeBody.startsWith('@@ ');

          final key = isNamedFile ? filePath : 'snippet_$globalSnippetIdx';

          if (isUnifiedDiff) {
            final cleanContent = _reconstructContentFromDiff(codeBody);
            upsertFile(
              key: key,
              name: fileName,
              path: filePath,
              language: _inferLanguage(fileName, fallback: 'diff'),
              content: cleanContent,
              rawDiffText: codeBody,
              toolOrigin: 'diff',
              isModificationOrCreation: true,
            );
          } else {
            upsertFile(
              key: key,
              name: fileName,
              path: filePath,
              language: lang,
              content: codeBody,
              toolOrigin: isNamedFile ? 'modified' : 'snippet',
              isModificationOrCreation: isNamedFile,
            );
          }
        }
      }
    }

    for (final manual in _manualReadFiles) {
      filesMap.putIfAbsent(manual.id, () => manual);
    }

    _allFiles = filesMap.values.toList();
    _activities = activitiesList.reversed.toList();

    final open = _openFiles;
    if (_selectedFileIndex >= open.length) {
      _selectedFileIndex = open.isEmpty ? 0 : open.length - 1;
    }
  }

  void _extractFromTool({
    required String name,
    required String inputRaw,
    required String? outputRaw,
    required DateTime timestamp,
    required bool isSuccess,
    required Map<String, VibeFileItem> filesMap,
    required void Function({
      required String key,
      required String name,
      required String path,
      required String language,
      required String content,
      String? explicitPreviousContent,
      String? rawDiffText,
      String? toolOrigin,
      bool isModificationOrCreation,
    }) upsertFile,
    required List<VibeActivityItem> activitiesList,
  }) {
    final lowerName = name.toLowerCase();
    Map<String, dynamic>? args;
    try {
      final decoded = jsonDecode(inputRaw);
      if (decoded is Map<String, dynamic>) {
        args = decoded;
      } else if (decoded is Map) {
        args = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (lowerName.contains('terminal') ||
        lowerName.contains('bash') ||
        lowerName.contains('exec') ||
        lowerName.contains('shell') ||
        lowerName == 'run_command') {
      final cmd =
          args?['command']?.toString() ??
          args?['cmd']?.toString() ??
          args?['script']?.toString() ??
          inputRaw.trim();
      activitiesList.add(
        VibeActivityItem(
          title: cmd.split('\n').first,
          type: isSuccess ? 'command' : 'error',
          detail: name,
          output: (outputRaw != null && outputRaw.trim().isNotEmpty)
              ? outputRaw
              : cmd,
          timestamp: timestamp,
          isSuccess: isSuccess,
        ),
      );
      return;
    }

    if (lowerName.contains('write') ||
        lowerName.contains('create') ||
        lowerName.contains('patch') ||
        lowerName.contains('edit') ||
        lowerName.contains('replace')) {
      final path =
          args?['path']?.toString() ??
          args?['file_path']?.toString() ??
          args?['filepath']?.toString() ??
          args?['target_file']?.toString() ??
          args?['filename']?.toString();

      final content =
          args?['content']?.toString() ??
          args?['file_text']?.toString() ??
          args?['new_str']?.toString() ??
          args?['new_string']?.toString() ??
          args?['replacement']?.toString() ??
          args?['new_text']?.toString() ??
          args?['code']?.toString();

      final oldText =
          args?['old_str']?.toString() ??
          args?['old_string']?.toString() ??
          args?['target']?.toString() ??
          args?['old_text']?.toString() ??
          args?['search']?.toString();

      final diffPatch =
          args?['diff']?.toString() ??
          args?['patch']?.toString();

      if (path != null && path.isNotEmpty) {
        final shortName = path.split(RegExp(r'[/\\]')).last;
        final existing = filesMap[path];

        if (diffPatch != null && diffPatch.trim().isNotEmpty) {
          final reconstructed = _reconstructContentFromDiff(diffPatch);
          upsertFile(
            key: path,
            name: shortName,
            path: path,
            language: _inferLanguage(shortName),
            content: reconstructed,
            rawDiffText: diffPatch,
            toolOrigin: name,
            isModificationOrCreation: true,
          );
        } else if (oldText != null && content != null) {
          String prev = oldText;
          String next = content;
          if (existing != null && existing.content.contains(oldText)) {
            prev = existing.content;
            next = existing.content.replaceFirst(oldText, content);
          }
          upsertFile(
            key: path,
            name: shortName,
            path: path,
            language: _inferLanguage(shortName),
            content: next,
            explicitPreviousContent: prev,
            toolOrigin: name,
            isModificationOrCreation: true,
          );
        } else if (content != null && content.isNotEmpty) {
          upsertFile(
            key: path,
            name: shortName,
            path: path,
            language: _inferLanguage(shortName),
            content: content,
            toolOrigin: name,
            isModificationOrCreation: true,
          );
        }
      }

      activitiesList.add(
        VibeActivityItem(
          title: path != null ? '$name: $path' : name,
          type: isSuccess ? 'tool' : 'error',
          detail: 'File change',
          output: outputRaw ?? inputRaw,
          timestamp: timestamp,
          isSuccess: isSuccess,
        ),
      );
      return;
    }

    if (lowerName.contains('read_file') || lowerName.contains('view_file')) {
      final path =
          args?['path']?.toString() ??
          args?['file_path']?.toString() ??
          args?['filepath']?.toString();
      if (path != null &&
          path.isNotEmpty &&
          outputRaw != null &&
          outputRaw.trim().isNotEmpty) {
        final shortName = path.split(RegExp(r'[/\\]')).last;
        if (!filesMap.containsKey(path)) {
          upsertFile(
            key: path,
            name: shortName,
            path: path,
            language: _inferLanguage(shortName),
            content: outputRaw,
            toolOrigin: name,
            isModificationOrCreation: false,
          );
        }
      }
      activitiesList.add(
        VibeActivityItem(
          title: path != null ? 'Read $path' : name,
          type: 'tool',
          detail: 'File inspection',
          output: outputRaw ?? inputRaw,
          timestamp: timestamp,
          isSuccess: isSuccess,
        ),
      );
      return;
    }

    activitiesList.add(
      VibeActivityItem(
        title: name,
        type: isSuccess ? 'tool' : 'error',
        detail: args != null && args.isNotEmpty
            ? args.entries
                  .take(2)
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', ')
            : null,
        output: outputRaw ?? inputRaw,
        timestamp: timestamp,
        isSuccess: isSuccess,
      ),
    );
  }

  /// Parses unified diff text into `VibeDiffLine` list and `(added, removed)` counts.
  (List<VibeDiffLine>, int, int) _parseUnifiedDiff(String rawDiff) {
    final lines = rawDiff.split('\n');
    final result = <VibeDiffLine>[];
    int added = 0;
    int removed = 0;
    int oldLine = 1;
    int newLine = 1;
    final hunkRegex = RegExp(r'^@@\s*-(\d+)(?:,\d+)?\s*\+(\d+)(?:,\d+)?\s*@@');

    for (final line in lines) {
      if (line.startsWith('diff --git ') ||
          line.startsWith('index ') ||
          line.startsWith('--- ') ||
          line.startsWith('+++ ')) {
        continue;
      }
      final hunkMatch = hunkRegex.firstMatch(line);
      if (hunkMatch != null) {
        oldLine = int.tryParse(hunkMatch.group(1) ?? '1') ?? 1;
        newLine = int.tryParse(hunkMatch.group(2) ?? '1') ?? 1;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.header,
            content: line,
          ),
        );
        continue;
      }
      if (line.startsWith('+')) {
        added++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.added,
            newLineNumber: newLine++,
            content: line.substring(1),
          ),
        );
      } else if (line.startsWith('-')) {
        removed++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.removed,
            oldLineNumber: oldLine++,
            content: line.substring(1),
          ),
        );
      } else {
        final clean = line.startsWith(' ') ? line.substring(1) : line;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.context,
            oldLineNumber: oldLine++,
            newLineNumber: newLine++,
            content: clean,
          ),
        );
      }
    }
    return (result, added, removed);
  }

  String _reconstructContentFromDiff(String rawDiff) {
    final lines = rawDiff.split('\n');
    final buffer = <String>[];
    for (final line in lines) {
      if (line.startsWith('diff --git ') ||
          line.startsWith('index ') ||
          line.startsWith('--- ') ||
          line.startsWith('+++ ') ||
          line.startsWith('@@ ')) {
        continue;
      }
      if (line.startsWith('-')) continue;
      if (line.startsWith('+')) {
        buffer.add(line.substring(1));
      } else if (line.startsWith(' ')) {
        buffer.add(line.substring(1));
      } else {
        buffer.add(line);
      }
    }
    return buffer.join('\n');
  }

  (List<VibeDiffLine>, int) _computeCreatedDiff(String content) {
    final lines = content.split('\n');
    final diff = <VibeDiffLine>[];
    for (int i = 0; i < lines.length; i++) {
      diff.add(
        VibeDiffLine(
          type: VibeDiffLineType.added,
          newLineNumber: i + 1,
          content: lines[i],
        ),
      );
    }
    return (diff, lines.length);
  }

  /// Computes a line-by-line LCS diff between `oldText` and `newText`.
  (List<VibeDiffLine>, int, int) _computeLineDiff(String oldText, String newText) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');

    // Trim common prefix and suffix to keep matrix small and fast
    int start = 0;
    while (start < oldLines.length &&
        start < newLines.length &&
        oldLines[start] == newLines[start]) {
      start++;
    }

    int endOld = oldLines.length - 1;
    int endNew = newLines.length - 1;
    while (endOld >= start &&
        endNew >= start &&
        oldLines[endOld] == newLines[endNew]) {
      endOld--;
      endNew--;
    }

    final result = <VibeDiffLine>[];
    int added = 0;
    int removed = 0;

    for (int i = 0; i < start; i++) {
      result.add(
        VibeDiffLine(
          type: VibeDiffLineType.context,
          oldLineNumber: i + 1,
          newLineNumber: i + 1,
          content: oldLines[i],
        ),
      );
    }

    final midOld = oldLines.sublist(start, endOld + 1);
    final midNew = newLines.sublist(start, endNew + 1);

    if (midOld.length * midNew.length <= 160000) {
      final m = midOld.length;
      final n = midNew.length;
      final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

      for (int i = m - 1; i >= 0; i--) {
        for (int j = n - 1; j >= 0; j--) {
          if (midOld[i] == midNew[j]) {
            dp[i][j] = 1 + dp[i + 1][j + 1];
          } else {
            final a = dp[i + 1][j];
            final b = dp[i][j + 1];
            dp[i][j] = a >= b ? a : b;
          }
        }
      }

      int i = 0;
      int j = 0;
      int curOld = start + 1;
      int curNew = start + 1;

      while (i < m && j < n) {
        if (midOld[i] == midNew[j]) {
          result.add(
            VibeDiffLine(
              type: VibeDiffLineType.context,
              oldLineNumber: curOld++,
              newLineNumber: curNew++,
              content: midOld[i],
            ),
          );
          i++;
          j++;
        } else if (dp[i + 1][j] >= dp[i][j + 1]) {
          removed++;
          result.add(
            VibeDiffLine(
              type: VibeDiffLineType.removed,
              oldLineNumber: curOld++,
              content: midOld[i],
            ),
          );
          i++;
        } else {
          added++;
          result.add(
            VibeDiffLine(
              type: VibeDiffLineType.added,
              newLineNumber: curNew++,
              content: midNew[j],
            ),
          );
          j++;
        }
      }

      while (i < m) {
        removed++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.removed,
            oldLineNumber: curOld++,
            content: midOld[i++],
          ),
        );
      }
      while (j < n) {
        added++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.added,
            newLineNumber: curNew++,
            content: midNew[j++],
          ),
        );
      }
    } else {
      int curOld = start + 1;
      for (final line in midOld) {
        removed++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.removed,
            oldLineNumber: curOld++,
            content: line,
          ),
        );
      }
      int curNew = start + 1;
      for (final line in midNew) {
        added++;
        result.add(
          VibeDiffLine(
            type: VibeDiffLineType.added,
            newLineNumber: curNew++,
            content: line,
          ),
        );
      }
    }

    int tailOld = endOld + 2;
    int tailNew = endNew + 2;
    for (int i = endOld + 1; i < oldLines.length; i++) {
      result.add(
        VibeDiffLine(
          type: VibeDiffLineType.context,
          oldLineNumber: tailOld++,
          newLineNumber: tailNew++,
          content: oldLines[i],
        ),
      );
    }

    return (result, added, removed);
  }

  String _summarizeReasoning(String text) {
    final firstLine = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => 'Thinking...');
    return firstLine.length > 75
        ? '${firstLine.substring(0, 75)}...'
        : firstLine;
  }

  (String, String, String, bool) _parseCodeBlockHeader(
    String header,
    String codeBody,
    int idx,
    String precedingText,
  ) {
    String lang = 'plaintext';
    String? detectedPath;

    final parts = header
        .split(RegExp(r'[\s:]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      final first = parts.first.toLowerCase();
      if (first.contains('.') || first.contains('/')) {
        detectedPath = parts.first;
        lang = _inferLanguage(detectedPath);
      } else {
        lang = first;
        if (parts.length > 1 &&
            (parts[1].contains('.') || parts[1].contains('/'))) {
          detectedPath = parts[1];
        }
      }
    }

    if (detectedPath == null) {
      final firstLine = codeBody.split('\n').first.trim();
      final commentFileMatch = RegExp(
        r'^(?://|#|/\*|--)\s*([a-zA-Z0-9_.\-/\\]+\.[a-zA-Z0-9]+)',
      ).firstMatch(firstLine);
      if (commentFileMatch != null) {
        detectedPath = commentFileMatch.group(1);
      }
    }

    if (detectedPath == null && precedingText.isNotEmpty) {
      final tail = precedingText.length > 220
          ? precedingText.substring(precedingText.length - 220)
          : precedingText;
      final backtickFileMatches = RegExp(
        r'`([a-zA-Z0-9_.\-/\\]+\.[a-zA-Z0-9]{1,8})`',
      ).allMatches(tail);
      if (backtickFileMatches.isNotEmpty) {
        detectedPath = backtickFileMatches.last.group(1);
      }
    }

    final isNamedFile = detectedPath != null && detectedPath.isNotEmpty;
    final ext = _extForLang(lang);
    final finalPath = isNamedFile ? detectedPath : 'snippet_$idx.$ext';
    final finalName = finalPath.split(RegExp(r'[/\\]')).last;
    if (lang == 'plaintext' && finalName.contains('.')) {
      lang = _inferLanguage(finalName);
    }

    return (lang, finalPath, finalName, isNamedFile);
  }

  String _inferLanguage(String filename, {String fallback = 'plaintext'}) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'py':
        return 'python';
      case 'js':
      case 'mjs':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'html':
        return 'xml';
      case 'css':
        return 'css';
      case 'rs':
        return 'rust';
      case 'go':
        return 'go';
      case 'kt':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'sql':
        return 'sql';
      case 'c':
      case 'cpp':
      case 'h':
        return 'cpp';
      default:
        return fallback;
    }
  }

  String _extForLang(String lang) {
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
      case 'rust':
      case 'rs':
        return 'rs';
      case 'go':
        return 'go';
      case 'sql':
        return 'sql';
      case 'diff':
      case 'patch':
        return 'diff';
      default:
        return 'txt';
    }
  }

  IconData _iconForLanguage(String lang) {
    switch (lang.toLowerCase()) {
      case 'dart':
      case 'python':
      case 'javascript':
      case 'typescript':
      case 'rust':
      case 'go':
      case 'cpp':
        return Icons.code_rounded;
      case 'json':
      case 'yaml':
        return Icons.data_object_rounded;
      case 'bash':
      case 'sh':
      case 'shell':
        return Icons.terminal_rounded;
      case 'diff':
      case 'patch':
        return Icons.difference_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  void _showSessionFilesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            decoration: BoxDecoration(
              color: HermesTokens.bgElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HermesTokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session File Changes',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: HermesTokens.textMuted,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_allFiles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No files modified or inspected in this session yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: HermesTokens.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _allFiles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final item = _allFiles[idx];
                          final open = _openFiles;
                          final isCurrent =
                              open.isNotEmpty &&
                              _selectedFileIndex < open.length &&
                              open[_selectedFileIndex].id == item.id;

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              _reopenOrSelectFile(item);
                              Navigator.of(ctx).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: isCurrent
                                  ? NeumorphicDecoration.recessed(radius: 14)
                                  : NeumorphicDecoration.raised(
                                      radius: 14,
                                      distance: 2,
                                      blur: 4,
                                    ),
                              child: Row(
                                children: [
                                  Icon(
                                    _iconForLanguage(item.language),
                                    size: 16,
                                    color: isCurrent
                                        ? HermesTokens.accent
                                        : HermesTokens.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            fontWeight: isCurrent
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isCurrent
                                                ? HermesTokens.accentText
                                                : HermesTokens.textPrimary,
                                          ),
                                        ),
                                        if (item.path != item.name) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.path,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10,
                                              color: HermesTokens.textMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (item.addedCount > 0 ||
                                      item.removedCount > 0) ...[
                                    const SizedBox(width: 8),
                                    _buildDiffStatText(
                                      item.addedCount,
                                      item.removedCount,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiffStatText(int added, int removed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (added > 0)
          Text(
            '+$added',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HermesTokens.success,
            ),
          ),
        if (added > 0 && removed > 0) const SizedBox(width: 6),
        if (removed > 0)
          Text(
            '-$removed',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HermesTokens.error,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final openFiles = _openFiles;
    return Container(
      color: HermesTokens.bgPrimary,
      child: Column(
        children: [
          if (_allFiles.isNotEmpty) _buildTopFileTabsBar(openFiles),
          Expanded(
            child: openFiles.isEmpty
                ? _buildEmptyWorkspaceState()
                : _buildInspectorView(
                    openFiles[_selectedFileIndex.clamp(0, openFiles.length - 1)],
                  ),
          ),
          _buildActivityDrawer(),
        ],
      ),
    );
  }

  Widget _buildTopFileTabsBar(List<VibeFileItem> openFiles) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: HermesTokens.bgPrimary,
        border: Border(bottom: BorderSide(color: HermesTokens.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _showSessionFilesSheet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: NeumorphicDecoration.raised(
                radius: 10,
                distance: 2,
                blur: 4,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 16,
                color: HermesTokens.accentText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: openFiles.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _allFiles.isEmpty
                          ? 'No files in session'
                          : '${_allFiles.length} session files available',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: openFiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final f = openFiles[idx];
                      final isSelected = idx == _selectedFileIndex;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _selectFileTab(idx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: isSelected
                              ? NeumorphicDecoration.recessed(radius: 10)
                              : NeumorphicDecoration.raised(
                                  radius: 10,
                                  distance: 1.5,
                                  blur: 3,
                                ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconForLanguage(f.language),
                                size: 13,
                                color: isSelected
                                    ? HermesTokens.accentText
                                    : HermesTokens.textMuted,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? HermesTokens.textPrimary
                                        : HermesTokens.textSecondary,
                                  ),
                                ),
                              ),
                              if (f.addedCount > 0 || f.removedCount > 0) ...[
                                const SizedBox(width: 6),
                                _buildDiffStatText(f.addedCount, f.removedCount),
                              ],
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _closeFileTab(f.id),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: HermesTokens.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorView(VibeFileItem file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showDiff = _showDiffView && file.hasDiff;
    final totalLines = file.content.split('\n').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action / Metadata Header
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$totalLines lines',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                          if (file.hasDiff) ...[
                            Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 10,
                                color: HermesTokens.textMuted,
                              ),
                            ),
                            _buildDiffStatText(file.addedCount, file.removedCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (file.hasDiff) ...[
                  _buildDiffCodeToggle(showDiff),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: file.content));
                    HapticFeedback.lightImpact();
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: NeumorphicDecoration.raised(
                      radius: 10,
                      distance: 1.5,
                      blur: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 13,
                          color: _copied
                              ? HermesTokens.success
                              : HermesTokens.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _copied
                                ? HermesTokens.success
                                : HermesTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Recessed Code / Diff Well
          Expanded(
            child: Container(
              decoration: NeumorphicDecoration.recessed(
                radius: 14,
                color: HermesTokens.codeBg,
              ),
              clipBehavior: Clip.antiAlias,
              child: showDiff
                  ? _buildDiffCanvas(file, isDark)
                  : _buildCodeCanvas(file, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffCodeToggle(bool showDiff) {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: NeumorphicDecoration.recessed(radius: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleSegment(
            label: 'Diff',
            selected: showDiff,
            onTap: () {
              if (!_showDiffView) {
                HapticFeedback.selectionClick();
                setState(() => _showDiffView = true);
              }
            },
          ),
          _toggleSegment(
            label: 'Code',
            selected: !showDiff,
            onTap: () {
              if (_showDiffView) {
                HapticFeedback.selectionClick();
                setState(() => _showDiffView = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _toggleSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: selected
            ? BoxDecoration(
                color: HermesTokens.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HermesTokens.borderBright, width: 0.8),
              )
            : const BoxDecoration(),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? HermesTokens.textPrimary : HermesTokens.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildDiffCanvas(VibeFileItem file, bool isDark) {
    final diffLines = file.diffLines;
    return ListView.builder(
      controller: _diffVerticalScroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: diffLines.length,
      itemBuilder: (context, index) {
        final line = diffLines[index];

        if (line.type == VibeDiffLineType.header) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: HermesTokens.accentSubtle,
            child: Text(
              line.content,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HermesTokens.accentText,
              ),
            ),
          );
        }

        Color rowBg = Colors.transparent;
        Color barColor = Colors.transparent;
        Color textColor = HermesTokens.textPrimary;
        String prefix = ' ';

        if (line.type == VibeDiffLineType.added) {
          rowBg = HermesTokens.success.withValues(alpha: isDark ? 0.14 : 0.12);
          barColor = HermesTokens.success;
          textColor = isDark
              ? const Color(0xFFA7F3D0)
              : const Color(0xFF065F46);
          prefix = '+';
        } else if (line.type == VibeDiffLineType.removed) {
          rowBg = HermesTokens.error.withValues(alpha: isDark ? 0.14 : 0.12);
          barColor = HermesTokens.error;
          textColor = isDark
              ? const Color(0xFFFECACA)
              : const Color(0xFF991B1B);
          prefix = '-';
        }

        final oldNum = line.oldLineNumber?.toString() ?? '';
        final newNum = line.newLineNumber?.toString() ?? '';

        return Container(
          color: rowBg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 20,
                color: barColor,
              ),
              SizedBox(
                width: 34,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4, top: 2),
                  child: Text(
                    oldNum,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      height: 1.5,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Text(
                    newNum,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      height: 1.5,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 14,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    prefix,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: barColor == Colors.transparent
                          ? HermesTokens.textMuted
                          : barColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14, top: 1, bottom: 1),
                    child: SelectableText(
                      line.content.isEmpty ? ' ' : line.content,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        height: 1.5,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCodeCanvas(VibeFileItem file, bool isDark) {
    final lines = file.content.split('\n');
    final lineNumsBuffer = List.generate(lines.length, (i) => '${i + 1}').join('\n');

    final baseTheme = isDark ? atomOneDarkTheme : atomOneLightTheme;
    final customTheme = Map<String, TextStyle>.from(baseTheme);
    customTheme['root'] = TextStyle(
      color: HermesTokens.textPrimary,
      backgroundColor: Colors.transparent,
    );

    return Scrollbar(
      controller: _codeVerticalScroll,
      child: SingleChildScrollView(
        controller: _codeVerticalScroll,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(left: 12, right: 10),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: HermesTokens.border),
                ),
              ),
              child: Text(
                lineNumsBuffer,
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  height: 1.55,
                  color: HermesTokens.textMuted,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: HighlightView(
                  file.content,
                  language: file.language,
                  theme: customTheme,
                  textStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkspaceState() {
    final quickActions = [
      (
        icon: Icons.account_tree_outlined,
        title: 'Inspect Architecture',
        subtitle: 'Map project structure and key modules',
        prompt:
            'Inspect the project structure and summarize the main architecture and entry points.',
      ),
      (
        icon: Icons.difference_rounded,
        title: 'Review Recent Changes',
        subtitle: 'Check git status and diff in workspace',
        prompt:
            'Check git status and git diff to summarize the current uncommitted changes.',
      ),
      (
        icon: Icons.bug_report_outlined,
        title: 'Find & Fix Bugs',
        subtitle: 'Run static analysis and resolve issues',
        prompt:
            'Analyze the codebase for errors or potential bugs and propose fixes.',
      ),
      (
        icon: Icons.playlist_add_check_rounded,
        title: 'Run Test Suite',
        subtitle: 'Execute tests and verify coverage',
        prompt:
            'Run the project test suite and report any failing tests with fixes.',
      ),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: NeumorphicDecoration.raised(radius: 16),
              child: Icon(
                Icons.difference_rounded,
                size: 24,
                color: HermesTokens.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No code changes in this session',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HermesTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Files read, created, or modified by the agent appear here with line-by-line diffs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: HermesTokens.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: quickActions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: widget.onQuickPrompt != null
                          ? () {
                              HapticFeedback.selectionClick();
                              widget.onQuickPrompt!(action.prompt);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: NeumorphicDecoration.raised(
                          radius: 14,
                          distance: 2.5,
                          blur: 6,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: NeumorphicDecoration.recessed(
                                radius: 10,
                              ),
                              child: Icon(
                                action.icon,
                                size: 17,
                                color: HermesTokens.accentText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: HermesTokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    action.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HermesTokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: HermesTokens.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityDrawer() {
    final latest = _activities.isNotEmpty ? _activities.first : null;
    final media = MediaQuery.of(context);
    final isKeyboardOpen = media.viewInsets.bottom > 0;
    final maxExpanded = (media.size.height * 0.35).clamp(140.0, 230.0);
    final drawerHeight = _terminalExpanded
        ? (isKeyboardOpen ? 120.0 : maxExpanded)
        : 40.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: drawerHeight,
      decoration: BoxDecoration(
        color: HermesTokens.bgSecondary,
        border: Border(
          top: BorderSide(color: HermesTokens.border),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _terminalExpanded = !_terminalExpanded);
            },
            child: SizedBox(
              height: 39,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (widget.isGenerating)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: HermesTokens.accent,
                        ),
                      )
                    else
                      Icon(
                        Icons.terminal_rounded,
                        size: 15,
                        color: HermesTokens.textMuted,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        latest != null
                            ? latest.title
                            : (widget.isGenerating
                                  ? 'Agent working...'
                                  : 'Activity log'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: HermesTokens.textSecondary,
                        ),
                      ),
                    ),
                    if (_activities.isNotEmpty) ...[
                      Text(
                        '${_activities.length} steps',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      _terminalExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: HermesTokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_terminalExpanded)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: HermesTokens.border),
                  ),
                ),
                child: _activities.isEmpty
                    ? Center(
                        child: Text(
                          'No tool executions recorded yet.',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: HermesTokens.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _activities.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: HermesTokens.border),
                        itemBuilder: (context, idx) {
                          final act = _activities[idx];
                          final isExpanded = _expandedActivityIdx == idx;

                          IconData actIcon = Icons.build_outlined;
                          Color iconColor = HermesTokens.textSecondary;
                          if (!act.isSuccess || act.type == 'error') {
                            actIcon = Icons.error_outline_rounded;
                            iconColor = HermesTokens.error;
                          } else if (act.type == 'command') {
                            actIcon = Icons.terminal_rounded;
                            iconColor = HermesTokens.accentText;
                          } else if (act.type == 'reasoning') {
                            actIcon = Icons.psychology_outlined;
                            iconColor = HermesTokens.textMuted;
                          }

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _expandedActivityIdx = isExpanded ? null : idx;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(actIcon, size: 14, color: iconColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          act.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: HermesTokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (act.detail != null &&
                                          act.detail!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            act.detail!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 10,
                                              color: HermesTokens.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 4),
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        size: 15,
                                        color: HermesTokens.textMuted,
                                      ),
                                    ],
                                  ),
                                  if (isExpanded &&
                                      act.output != null &&
                                      act.output!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: NeumorphicDecoration.recessed(
                                        radius: 10,
                                        color: HermesTokens.codeBg,
                                      ),
                                      child: SelectableText(
                                        act.output!.length > 2000
                                            ? '${act.output!.substring(0, 2000)}\n... (truncated)'
                                            : act.output!,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          height: 1.45,
                                          color: HermesTokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
}
