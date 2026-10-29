import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/connection_provider.dart';
import '../../../../theme.dart';
import '../../../widgets/expandable_text.dart';
import '../../../widgets/neumorphic_skeleton.dart';
import '../capabilities_providers.dart';
import 'capabilities_common_widgets.dart';

class McpTab extends ConsumerStatefulWidget {
  const McpTab({super.key});

  @override
  ConsumerState<McpTab> createState() => _McpTabState();
}

class _McpTabState extends ConsumerState<McpTab> {
  final _mcpSearchCtrl = TextEditingController();
  int _mcpTabSegment = 0; // 0: Configured, 1: Catalog

  @override
  void dispose() {
    _mcpSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mcpAsync = ref.watch(mcpServersProvider);
    final catalogAsync = ref.watch(mcpCatalogProvider);
    return RefreshIndicator(
      color: HermesTokens.accent,
      backgroundColor: HermesTokens.bgElevated,
      onRefresh: () async {
        ref.invalidate(mcpServersProvider);
        ref.invalidate(mcpCatalogProvider);
        try {
          await Future.wait([
            ref.read(mcpServersProvider.future),
            ref.read(mcpCatalogProvider.future),
          ]);
        } catch (_) {}
      },
      child: Builder(
        builder: (context) {
          final servers = mcpAsync.valueOrNull ?? [];
          final catalog = catalogAsync.valueOrNull ?? [];

          final isLoading = (mcpAsync.isLoading && servers.isEmpty) ||
              (catalogAsync.isLoading && catalog.isEmpty && _mcpTabSegment == 1);

          if (isLoading) {
            return const CapabilityListSkeleton();
          }

          if (mcpAsync.hasError && servers.isEmpty && catalogAsync.hasError && catalog.isEmpty) {
            return CapabilitiesConnectionFailedState(
              mcpAsync.error.toString(),
              () {
                ref.invalidate(mcpServersProvider);
                ref.invalidate(mcpCatalogProvider);
              },
            );
          }

          final query = _mcpSearchCtrl.text.trim().toLowerCase();

          final filteredServers = servers.where((s) {
            final name = s['name']?.toString().toLowerCase() ?? '';
            final desc = s['description']?.toString().toLowerCase() ?? '';
            return query.isEmpty || name.contains(query) || desc.contains(query);
          }).toList();

          final filteredCatalog = catalog.where((c) {
            final name = c['name']?.toString().toLowerCase() ?? '';
            final desc = c['description']?.toString().toLowerCase() ?? '';
            return query.isEmpty || name.contains(query) || desc.contains(query);
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Segment switcher (Configured vs Catalog)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    height: 40,
                    decoration: NeumorphicDecoration.recessed(radius: 12),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mcpTabSegment = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: _mcpTabSegment == 0
                                  ? BoxDecoration(
                                      color: HermesTokens.accent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x332563EB), blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    )
                                  : null,
                              alignment: Alignment.center,
                              child: Text(
                                "Configured (${servers.length})",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _mcpTabSegment == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: _mcpTabSegment == 0 ? Colors.white : HermesTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _mcpTabSegment = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: _mcpTabSegment == 1
                                  ? BoxDecoration(
                                      color: HermesTokens.accent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x332563EB), blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    )
                                  : null,
                              alignment: Alignment.center,
                              child: Text(
                                "Catalog (${catalog.length})",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _mcpTabSegment == 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: _mcpTabSegment == 1 ? Colors.white : HermesTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search input
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    decoration: NeumorphicDecoration.recessed(radius: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _mcpSearchCtrl,
                      style: TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _mcpTabSegment == 0
                            ? "Search ${servers.length} configured servers..."
                            : "Search catalog of ${catalog.length} MCP tools...",
                        hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
                                onPressed: () {
                                  _mcpSearchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),

              // Header info count
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                  child: Row(
                    children: [
                      Text(
                        _mcpTabSegment == 0
                            ? "${filteredServers.length} CONFIGURED SERVERS"
                            : "${filteredCatalog.length} AVAILABLE IN CATALOG",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (_mcpTabSegment == 1)
                        Text(
                          "Tap card to install",
                          style: TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
              ),

              // Content sliver
              if (_mcpTabSegment == 0) ...[
                if (filteredServers.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              query.isNotEmpty ? "No matching MCP servers found" : "No MCP servers configured yet",
                              style: TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                            ),
                            if (query.isEmpty) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () => setState(() => _mcpTabSegment = 1),
                                style: FilledButton.styleFrom(
                                  backgroundColor: HermesTokens.bgSecondary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text("Explore Catalog", style: TextStyle(color: HermesTokens.accent)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = filteredServers[index];
                          final name = s['name']?.toString() ?? 'Server';
                          final desc = s['description']?.toString() ?? 'Model Context Protocol';
                          final enabled = s['enabled'] as bool? ?? true;
                          final transport = s['transport']?.toString() ?? 'stdio';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: NeumorphicDecoration.raised(radius: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: HermesTokens.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            transport,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: HermesTokens.textMuted,
                                              fontFamily: 'JetBrains Mono',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      ExpandableText(
                                        text: desc,
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Switch.adaptive(
                                  value: enabled,
                                  activeThumbColor: HermesTokens.accent,
                                  onChanged: (val) async {
                                    final conn = ref.read(connectionProvider).valueOrNull;
                                    if (conn != null) {
                                      await conn.setMcpServerEnabled(name, val);
                                      ref.invalidate(mcpServersProvider);
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _confirmUninstallMcpServer(name),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.delete_outline_rounded, size: 18, color: HermesTokens.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: filteredServers.length,
                      ),
                    ),
                  ),
              ] else ...[
                if (filteredCatalog.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          query.isNotEmpty ? "No catalog entries match '$query'" : "No catalog entries available from Hermes daemon",
                          style: TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final c = filteredCatalog[index];
                          final name = c['name']?.toString() ?? 'Server';
                          final desc = c['description']?.toString() ?? 'MCP Tool';
                          final installed = c['installed'] as bool? ?? false;
                          final transport = c['transport']?.toString() ?? 'stdio';
                          final rawEnv = c['required_env'];
                          final bool hasEnv = rawEnv is List && rawEnv.isNotEmpty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: NeumorphicDecoration.raised(radius: 16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showInstallMcpDialog(c),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: HermesTokens.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  transport,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: HermesTokens.textMuted,
                                                    fontFamily: 'JetBrains Mono',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ExpandableText(
                                              text: desc,
                                              maxLines: 2,
                                            ),
                                            if (hasEnv) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                "Requires env configuration",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: HermesTokens.accentText,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (installed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: HermesTokens.bgSecondary,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: HermesTokens.border),
                                          ),
                                          child: Text(
                                            "Installed",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: HermesTokens.textSecondary,
                                            ),
                                          ),
                                        )
                                      else
                                        FilledButton(
                                          onPressed: () => _showInstallMcpDialog(c),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: HermesTokens.accent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            "Install",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filteredCatalog.length,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInstallMcpDialog(Map<String, dynamic> entry) async {
    final name = entry['name']?.toString() ?? '';
    final desc = entry['description']?.toString() ?? '';
    final transport = entry['transport']?.toString() ?? 'stdio';
    final rawEnv = entry['required_env'];
    final List<Map<String, dynamic>> requiredEnvs = [];
    if (rawEnv is List) {
      for (final e in rawEnv) {
        if (e is Map) {
          requiredEnvs.add(Map<String, dynamic>.from(e));
        } else if (e is String) {
          requiredEnvs.add({'name': e, 'prompt': e, 'required': true});
        }
      }
    }

    final controllers = <String, TextEditingController>{};
    for (final e in requiredEnvs) {
      final envName = e['name']?.toString() ?? '';
      if (envName.isNotEmpty) {
        controllers[envName] = TextEditingController();
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: HermesTokens.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Install $name",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isNotEmpty ? desc : "Install this Model Context Protocol server onto your Hermes host.",
                  style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Transport: $transport",
                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                ),
                if (requiredEnvs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    "REQUIRED CONFIGURATION",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final e in requiredEnvs) ...[
                    Builder(
                      builder: (context) {
                        final envName = e['name']?.toString().toLowerCase() ?? '';
                        final isSecret = e['secret'] == true || envName.contains('key') || envName.contains('token') || envName.contains('password');
                        final isNum = e['type'] == 'number' || envName.contains('port') || envName.contains('timeout');
                        final isUrl = envName.contains('url') || envName.contains('endpoint');
                        final kType = isNum
                            ? TextInputType.number
                            : (isSecret
                                ? TextInputType.visiblePassword
                                : (isUrl ? TextInputType.url : TextInputType.text));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['prompt']?.toString() ?? e['name']?.toString() ?? '',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: NeumorphicDecoration.recessed(radius: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: TextField(
                                controller: controllers[e['name']?.toString() ?? ''],
                                keyboardType: kType,
                                obscureText: isSecret,
                                style: TextStyle(fontSize: 12, color: HermesTokens.textPrimary),
                                decoration: InputDecoration(
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: e['name']?.toString() ?? 'Value',
                                  hintStyle: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: HermesTokens.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Install"),
            ),
          ],
        ),
      ),
    );

    for (final c in controllers.values) {
      c.dispose();
    }

    if (ok != true || !mounted) return;

    final envValues = <String, String>{};
    for (final entry in controllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        envValues[entry.key] = entry.value.text.trim();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Installing $name MCP server..."),
        duration: const Duration(seconds: 2),
      ),
    );

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      final success = await conn.installMcpCatalogEntry(name, envValues);
      if (!mounted) return;
      if (success) {
        ref.invalidate(mcpServersProvider);
        ref.invalidate(mcpCatalogProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Successfully installed $name!"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to install $name. Please check daemon logs."),
            backgroundColor: HermesTokens.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmUninstallMcpServer(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Uninstall $name?",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Text(
          "Are you sure you want to remove the '$name' MCP server from your Hermes profile?",
          style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: HermesTokens.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Uninstall"),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      final success = await conn.uninstallMcpServer(name);
      if (!mounted) return;
      if (success) {
        ref.invalidate(mcpServersProvider);
        ref.invalidate(mcpCatalogProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Uninstalled $name")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to uninstall $name"), backgroundColor: HermesTokens.error),
        );
      }
    }
  }


}
