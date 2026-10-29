import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/connection_provider.dart';
import '../../../../theme.dart';
import '../../../widgets/neumorphic_skeleton.dart';
import '../../../widgets/expandable_text.dart';
import '../capabilities_providers.dart';
import 'capabilities_common_widgets.dart';

class PluginsTab extends ConsumerStatefulWidget {
  const PluginsTab({super.key});

  @override
  ConsumerState<PluginsTab> createState() => _PluginsTabState();
}

class _PluginsTabState extends ConsumerState<PluginsTab> {
  final _pluginSearchCtrl = TextEditingController();
  int _pluginTabSegment = 0; // 0: Installed, 1: Catalog
  final Set<String> _pendingPluginOps = {};

  @override
  void dispose() {
    _pluginSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _togglePlugin(String name, bool enabled) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    setState(() => _pendingPluginOps.add(name));

    final success = await conn.setPluginEnabled(name, enabled);
    if (!mounted) return;

    setState(() => _pendingPluginOps.remove(name));

    if (success) {
      ref.invalidate(pluginsProvider);
      ref.invalidate(pluginCatalogProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? "Enabled $name" : "Disabled $name")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to ${enabled ? 'enable' : 'disable'} $name"),
          backgroundColor: HermesTokens.error,
        ),
      );
    }
  }

  Future<void> _confirmUninstallPlugin(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Uninstall Plugin",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Text(
          "Are you sure you want to remove the '$name' plugin from your Hermes instance?",
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
      final success = await conn.uninstallPlugin(name);
      if (!mounted) return;
      if (success) {
        ref.invalidate(pluginsProvider);
        ref.invalidate(pluginCatalogProvider);
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

  Future<void> _showInstallPluginDialog(Map<String, dynamic> entry, {String? hostOs}) async {
    final name = entry['name']?.toString() ?? '';
    final desc = entry['description']?.toString() ?? 'Hermes Agent Plugin';
    final repo = entry['repo']?.toString() ?? '';
    final summary = entry['capability_summary']?.toString() ?? '';
    final maintainer = entry['maintainer']?.toString() ?? '';

    final rawPlatforms = entry['platforms'];
    final List<String> platforms = (rawPlatforms is List)
        ? rawPlatforms.map((p) => p.toString().toLowerCase().trim()).where((p) => p.isNotEmpty).toList()
        : [];

    final caps = entry['capabilities'] as Map? ?? {};
    final requiresEnv = (caps['requires_env'] as List?)?.map((e) => e.toString()).toList() ?? [];

    bool isCompatible = true;
    String? incompatibilityReason;

    if (platforms.isNotEmpty && hostOs != null && hostOs.isNotEmpty) {
      final h = hostOs.toLowerCase();
      final isHostWindows = h.contains('win');
      final isHostLinux = h.contains('linux');
      final isHostMac = h.contains('mac') || h.contains('darwin');

      final supportedNorm = platforms.map((p) {
        if (p == 'windows' || p == 'win32') return 'win';
        if (p == 'linux') return 'linux';
        if (p == 'macos' || p == 'darwin') return 'mac';
        return p;
      }).toSet();

      if (isHostWindows && !supportedNorm.contains('win')) {
        isCompatible = false;
        incompatibilityReason = "This plugin only supports: ${platforms.join(', ')}. The Hermes daemon is running on Windows ($hostOs), so the installation will be rejected by the host daemon.";
      } else if (isHostLinux && !supportedNorm.contains('linux')) {
        isCompatible = false;
        incompatibilityReason = "This plugin only supports: ${platforms.join(', ')}. The Hermes daemon is running on Linux ($hostOs).";
      } else if (isHostMac && !supportedNorm.contains('mac')) {
        isCompatible = false;
        incompatibilityReason = "This plugin only supports: ${platforms.join(', ')}. The Hermes daemon is running on macOS ($hostOs).";
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.extension_outlined, size: 20, color: HermesTokens.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Install $name",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
              ),
            ),
          ],
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
                if (!isCompatible) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_rounded, size: 20, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Host Platform Incompatible",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                incompatibilityReason ?? "This plugin is not compatible with the host operating system.",
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: HermesTokens.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HermesTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "REQUIREMENTS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: HermesTokens.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Platform: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
                          Expanded(
                            child: Text(
                              platforms.isNotEmpty ? platforms.map((p) => p.toUpperCase()).join(', ') : "All platforms (Cross-platform)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isCompatible ? HermesTokens.textPrimary : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (requiresEnv.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Env Vars: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
                            Expanded(
                              child: Text(
                                requiresEnv.join(', '),
                                style: TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: HermesTokens.accentText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (maintainer.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text("Maintainer: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
                            Text(
                              maintainer,
                              style: TextStyle(fontSize: 11, color: HermesTokens.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
                if (repo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Source: $repo",
                    style: TextStyle(fontSize: 11, color: HermesTokens.textMuted, fontFamily: 'JetBrains Mono'),
                  ),
                ],
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HermesTokens.bgSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HermesTokens.border),
                    ),
                    child: Text(
                      summary,
                      style: TextStyle(fontSize: 11, color: HermesTokens.textSecondary, height: 1.3),
                    ),
                  ),
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
              backgroundColor: isCompatible ? HermesTokens.accent : const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCompatible ? "Install" : "Install Anyway"),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    setState(() => _pendingPluginOps.add(name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Installing $name from catalog...")),
    );

    final success = await conn.installPlugin(name);
    if (!mounted) return;

    setState(() => _pendingPluginOps.remove(name));

    if (success) {
      ref.invalidate(pluginsProvider);
      ref.invalidate(pluginCatalogProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plugin '$name' installed successfully")),
      );
    } else {
      final err = conn.lastPluginError;
      final msg = (err != null && err.isNotEmpty)
          ? err
          : "Failed to install plugin '$name'";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: HermesTokens.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pluginsAsync = ref.watch(pluginsProvider);
    final catalogAsync = ref.watch(pluginCatalogProvider);
    return RefreshIndicator(
      color: HermesTokens.accent,
      backgroundColor: HermesTokens.bgElevated,
      onRefresh: () async {
        ref.invalidate(pluginsProvider);
        ref.invalidate(pluginCatalogProvider);
        try {
          await Future.wait([
            ref.read(pluginsProvider.future),
            ref.read(pluginCatalogProvider.future),
          ]);
        } catch (_) {}
      },
      child: Builder(
        builder: (context) {
          final stats = ref.watch(systemStatsProvider).valueOrNull;
          final hostOs = (stats?['os'] ?? stats?['platform'] ?? '').toString();

          final isPluginsLoading = pluginsAsync.isLoading && !pluginsAsync.hasValue;
          final isCatalogLoading = catalogAsync.isLoading && !catalogAsync.hasValue;

          if (isPluginsLoading && isCatalogLoading) {
            return const CapabilityListSkeleton();
          }

          final plugins = pluginsAsync.valueOrNull ?? [];
          final catalog = catalogAsync.valueOrNull ?? [];

          final query = _pluginSearchCtrl.text.trim().toLowerCase();

          final filteredInstalled = plugins.where((p) {
            final name = (p['name'] ?? p['label'] ?? '').toString().toLowerCase();
            final desc = (p['description'] ?? '').toString().toLowerCase();
            return query.isEmpty || name.contains(query) || desc.contains(query);
          }).toList();

          final filteredCatalog = catalog.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final desc = (c['description'] ?? '').toString().toLowerCase();
            final cat = (c['category'] ?? '').toString().toLowerCase();
            return query.isEmpty || name.contains(query) || desc.contains(query) || cat.contains(query);
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Segment switcher (Installed vs Catalog)
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
                            onTap: () => setState(() => _pluginTabSegment = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: _pluginTabSegment == 0
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
                                "Installed (${plugins.length})",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _pluginTabSegment == 0 ? FontWeight.w700 : FontWeight.w500,
                                  color: _pluginTabSegment == 0 ? Colors.white : HermesTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _pluginTabSegment = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: _pluginTabSegment == 1
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
                                  fontWeight: _pluginTabSegment == 1 ? FontWeight.w700 : FontWeight.w500,
                                  color: _pluginTabSegment == 1 ? Colors.white : HermesTokens.textSecondary,
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

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    decoration: NeumorphicDecoration.recessed(radius: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _pluginSearchCtrl,
                      style: TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _pluginTabSegment == 0
                            ? "Search ${plugins.length} installed plugins..."
                            : "Search catalog of ${catalog.length} plugins...",
                        hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
                                onPressed: () {
                                  _pluginSearchCtrl.clear();
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

              // Count & subtitle info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                  child: Row(
                    children: [
                      Text(
                        _pluginTabSegment == 0
                            ? "${filteredInstalled.length} INSTALLED PLUGINS"
                            : "${filteredCatalog.length} AVAILABLE IN CATALOG",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (_pluginTabSegment == 1)
                        Text(
                          "Tap card to install",
                          style: TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
              ),

              // Content Sliver
              if (_pluginTabSegment == 0) ...[
                if (filteredInstalled.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          query.isNotEmpty
                              ? "No installed plugins match '$query'"
                              : "No plugins installed on this Hermes daemon",
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
                          final p = filteredInstalled[index];
                          final name = (p['name'] ?? p['label'] ?? 'Plugin').toString();
                          final desc = (p['description'] ?? '').toString();
                          final ver = (p['version'] ?? '').toString();
                          final source = (p['source'] ?? '').toString().toLowerCase();
                          final isBundled = source == "bundled";
                          final runtimeStatus = (p['runtime_status'] ?? '').toString().toLowerCase();
                          final isEnabled = runtimeStatus == "enabled" || p['enabled'] == true;
                          final canRemove = (p['can_remove_update'] == true || (!isBundled && source.isNotEmpty)) && !isBundled;
                          final isPending = _pendingPluginOps.contains(name);

                          final isKanban = name.toLowerCase().contains('kanban');
                          final isAchievements = name.toLowerCase().contains('achievement');
                          final isBuiltInCore = isKanban || isAchievements;
                          final hasDirectAction = isKanban || isAchievements;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: NeumorphicDecoration.raised(radius: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: HermesTokens.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (ver.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  "v$ver",
                                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              // Source badge (Bundled / User)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isBundled
                                                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                                      : const Color(0xFF06B6D4).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isBundled ? "BUNDLED" : "USER",
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                    color: isBundled ? const Color(0xFF4F46E5) : const Color(0xFF0891B2),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Status badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isEnabled
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                      : const Color(0xFF64748B).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isEnabled ? "ACTIVE" : "DISABLED",
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                    color: isEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (isPending)
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                                      )
                                    else if (!isBuiltInCore) ...[
                                      Switch.adaptive(
                                        value: isEnabled,
                                        activeThumbColor: HermesTokens.accent,
                                        onChanged: (val) => _togglePlugin(name, val),
                                      ),
                                      if (canRemove) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _confirmUninstallPlugin(name),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(Icons.delete_outline_rounded, size: 18, color: HermesTokens.textMuted),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ExpandableText(
                                    text: desc,
                                    maxLines: 2,
                                  ),
                                ],
                                if (hasDirectAction) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        if (isKanban) context.push('/kanban');
                                        if (isAchievements) context.push('/achievements');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: HermesTokens.accent),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: Icon(
                                        isKanban ? Icons.view_kanban_outlined : Icons.emoji_events_outlined,
                                        size: 14,
                                        color: HermesTokens.accent,
                                      ),
                                      label: Text(
                                        isKanban ? "Open Kanban Board" : "Open Achievements",
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.accent),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                        childCount: filteredInstalled.length,
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
                          query.isNotEmpty
                              ? "No catalog entries match '$query'"
                              : "No catalog entries returned from Hermes daemon",
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
                          final name = (c['name'] ?? 'Plugin').toString();
                          final installed = c['installed'] as bool? ?? false;
                          final isPending = _pendingPluginOps.contains(name);

                          return _CatalogPluginCard(
                            entry: c,
                            installed: installed,
                            isPending: isPending,
                            categoryFormatted: formatCapabilityCategory((c['category'] ?? '').toString()),
                            hostOs: hostOs,
                            onInstall: () => _showInstallPluginDialog(c, hostOs: hostOs),
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

  IconData getIconForCapabilitySkill(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('image')) return Icons.image_outlined;
    if (lower.contains('translation') || lower.contains('translate')) return Icons.translate_outlined;
    if (lower.contains('privacy') || lower.contains('shield')) return Icons.shield_outlined;
    if (lower.contains('code') || lower.contains('programming') || lower.contains('codex') || lower.contains('claude')) {
      return Icons.code_outlined;
    }
    if (lower.contains('logic') || lower.contains('reason') || lower.contains('agent')) return Icons.psychology_outlined;
    if (lower.contains('core') || lower.contains('engine') || lower.contains('computer')) return Icons.computer_outlined;
    if (lower.contains('speed') || lower.contains('turbo')) return Icons.speed_outlined;
    if (lower.contains('video') || lower.contains('media')) return Icons.movie_outlined;
    if (lower.contains('web') || lower.contains('search')) return Icons.language_outlined;
    return Icons.build_outlined;
  }


}

class _CatalogPluginCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final bool installed;
  final bool isPending;
  final String categoryFormatted;
  final String? hostOs;
  final VoidCallback onInstall;

  const _CatalogPluginCard({
    required this.entry,
    required this.installed,
    required this.isPending,
    required this.categoryFormatted,
    this.hostOs,
    required this.onInstall,
  });

  @override
  State<_CatalogPluginCard> createState() => _CatalogPluginCardState();
}

class _CatalogPluginCardState extends State<_CatalogPluginCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.entry;
    final name = (c['name'] ?? 'Plugin').toString();
    final desc = (c['description'] ?? 'Hermes Agent Plugin').toString();
    final summary = (c['capability_summary'] ?? '').toString();
    final tier = (c['tier'] ?? '').toString().toLowerCase();
    final maintainer = (c['maintainer'] ?? '').toString();
    final repo = (c['repo'] ?? '').toString();
    final sha = (c['sha_short'] ?? (c['sha'] != null && c['sha'].toString().length >= 7 ? c['sha'].toString().substring(0, 7) : '')).toString();

    final rawPlatforms = c['platforms'];
    final List<String> platforms = (rawPlatforms is List)
        ? rawPlatforms.map((p) => p.toString().toLowerCase().trim()).where((p) => p.isNotEmpty).toList()
        : [];

    final caps = c['capabilities'] as Map? ?? {};
    final tools = (caps['provides_tools'] as List?) ?? [];
    final requiresEnv = (caps['requires_env'] as List?)?.map((e) => e.toString()).toList() ?? [];

    bool isCompatible = true;
    String? platformRequirementLabel;

    if (platforms.isNotEmpty && widget.hostOs != null && widget.hostOs!.isNotEmpty) {
      final h = widget.hostOs!.toLowerCase();
      final isHostWindows = h.contains('win');
      final isHostLinux = h.contains('linux');
      final isHostMac = h.contains('mac') || h.contains('darwin');

      final supportedNorm = platforms.map((p) {
        if (p == 'windows' || p == 'win32') return 'win';
        if (p == 'linux') return 'linux';
        if (p == 'macos' || p == 'darwin') return 'mac';
        return p;
      }).toSet();

      if (isHostWindows && !supportedNorm.contains('win')) {
        isCompatible = false;
        platformRequirementLabel = "${platforms.join(', ').toUpperCase()} ONLY (Host: Win32)";
      } else if (isHostLinux && !supportedNorm.contains('linux')) {
        isCompatible = false;
        platformRequirementLabel = "Incompatible with Linux";
      } else if (isHostMac && !supportedNorm.contains('mac')) {
        isCompatible = false;
        platformRequirementLabel = "Incompatible with macOS";
      }
    }

    final hasDetails = desc.length > 90 || summary.isNotEmpty || maintainer.isNotEmpty || requiresEnv.isNotEmpty || repo.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: NeumorphicDecoration.raised(radius: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.installed ? null : widget.onInstall,
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
                      // Header Row: Name + Tier + Category
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HermesTokens.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tier.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: tier == 'official'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : HermesTokens.bgSecondary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: tier == 'official'
                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                      : HermesTokens.border,
                                ),
                              ),
                              child: Text(
                                tier,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: tier == 'official' ? const Color(0xFF059669) : HermesTokens.textMuted,
                                ),
                              ),
                            ),
                          ],
                          if (widget.categoryFormatted.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: HermesTokens.bgSecondary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: HermesTokens.border),
                              ),
                              child: Text(
                                widget.categoryFormatted,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: HermesTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Requirements and Platform Chips Row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!isCompatible)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.block_rounded, size: 10, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 3),
                                  Text(
                                    platformRequirementLabel ?? "REQUIRES ${platforms.join(', ').toUpperCase()}",
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (platforms.isNotEmpty)
                            ...platforms.map((p) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HermesTokens.bgSecondary,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: HermesTokens.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        p == 'linux'
                                            ? Icons.terminal_rounded
                                            : (p.contains('win') ? Icons.window_rounded : Icons.laptop_mac_rounded),
                                        size: 10,
                                        color: HermesTokens.textMuted,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        p.toUpperCase(),
                                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary),
                                      ),
                                    ],
                                  ),
                                ))
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: HermesTokens.bgSecondary,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: HermesTokens.border),
                              ),
                              child: Text(
                                "CROSS-PLATFORM",
                                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: HermesTokens.textMuted),
                              ),
                            ),
                          if (requiresEnv.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                "env: ${requiresEnv.first}${requiresEnv.length > 1 ? ' +${requiresEnv.length - 1}' : ''}",
                                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                              ),
                            ),
                          if (tools.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: HermesTokens.bgSecondary,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: HermesTokens.border),
                              ),
                              child: Text(
                                "${tools.length} tools",
                                style: TextStyle(fontSize: 8.5, color: HermesTokens.textMuted),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Paragraph 1: Description
                      Text(
                        desc,
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: HermesTokens.textMuted,
                          height: 1.35,
                        ),
                      ),
                      // Paragraph 2: Technical capabilities & requirements summary when expanded
                      if (_expanded) ...[
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: HermesTokens.bgSecondary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HermesTokens.border),
                            ),
                            child: Text(
                              summary,
                              style: TextStyle(
                                fontSize: 10,
                                color: HermesTokens.accentText,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: HermesTokens.bgSecondary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HermesTokens.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (platforms.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    "Supported OS: ${platforms.map((p) => p.toUpperCase()).join(', ')}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isCompatible ? HermesTokens.textSecondary : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              if (requiresEnv.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    "Required Env: ${requiresEnv.join(', ')}",
                                    style: TextStyle(fontSize: 10, color: HermesTokens.textSecondary),
                                  ),
                                ),
                              if (maintainer.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    "Maintainer: $maintainer",
                                    style: TextStyle(fontSize: 10, color: HermesTokens.textSecondary),
                                  ),
                                ),
                              if (repo.isNotEmpty)
                                Text(
                                  sha.isNotEmpty ? "Source: $repo ($sha)" : "Source: $repo",
                                  style: TextStyle(fontSize: 10, color: HermesTokens.textMuted, fontFamily: 'JetBrains Mono'),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Single unified "Read more" / "Show less" toggle
                      if (hasDetails) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() => _expanded = !_expanded);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2, right: 8),
                            child: Text(
                              _expanded ? "Show less" : "Read more",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: HermesTokens.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.isPending)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                  )
                else if (widget.installed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          "Installed",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isCompatible)
                  OutlinedButton.icon(
                    onPressed: widget.onInstall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFF87171)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                    label: Text(
                      platforms.isNotEmpty ? "${platforms.first} only" : "Incompatible",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: widget.onInstall,
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
  }
}
