import "package:flutter/material.dart";
import "package:flutter_markdown/flutter_markdown.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "../widgets/expandable_text.dart";
import "../widgets/neumorphic_skeleton.dart";

final skillsProvider = FutureProvider<List<SkillInfo>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getSkills();
});

final toolsetsProvider = FutureProvider<List<ToolsetInfo>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getToolsets();
});

final mcpServersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getMcpServers();
});

final mcpCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getMcpCatalog();
});

final pluginsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getPlugins();
});

final pluginCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getPluginCatalog();
});

final systemStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return null;
  return conn.getSystemStats();
});

class CapabilitiesScreen extends ConsumerStatefulWidget {
  const CapabilitiesScreen({super.key});
  @override
  ConsumerState<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends ConsumerState<CapabilitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _skillSearchCtrl = TextEditingController();
  final _toolsetSearchCtrl = TextEditingController();
  final _mcpSearchCtrl = TextEditingController();
  final _pluginSearchCtrl = TextEditingController();
  int _mcpTabSegment = 0; // 0: Configured, 1: Catalog
  int _pluginTabSegment = 0; // 0: Installed, 1: Catalog
  final Set<String> _pendingPluginOps = {};
  String _selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _skillSearchCtrl.dispose();
    _toolsetSearchCtrl.dispose();
    _mcpSearchCtrl.dispose();
    _pluginSearchCtrl.dispose();
    super.dispose();
  }

  String _formatCategory(String cat) {
    if (cat.isEmpty) return "General";
    return cat.replaceAll("-", " ").split(" ").map((w) {
      if (w.isEmpty) return "";
      return w[0].toUpperCase() + w.substring(1);
    }).join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);
    final toolsetsAsync = ref.watch(toolsetsProvider);
    final mcpAsync = ref.watch(mcpServersProvider);
    final mcpCatalogAsync = ref.watch(mcpCatalogProvider);
    final pluginsAsync = ref.watch(pluginsProvider);
    final pluginCatalogAsync = ref.watch(pluginCatalogProvider);

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 54,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                    child: IconButton(
                      tooltip: "Back",
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              )
            : null,
        title: const Text(
          "Capabilities",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 44,
              decoration: NeumorphicDecoration.recessed(radius: 14),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: HermesTokens.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D2563EB),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: HermesTokens.textSecondary,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Skills"),
                  Tab(text: "Toolsets"),
                  Tab(text: "MCP"),
                  Tab(text: "Plugins"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSkillsTab(skillsAsync),
          _buildToolsetsTab(toolsetsAsync),
          _buildMcpTab(mcpAsync, mcpCatalogAsync),
          _buildPluginTab(pluginsAsync, pluginCatalogAsync),
        ],
      ),
    );
  }

  Widget _buildSkillsTab(AsyncValue<List<SkillInfo>> skillsAsync) {
    return RefreshIndicator(
      color: HermesTokens.accent,
      backgroundColor: HermesTokens.bgElevated,
      onRefresh: () async {
        ref.invalidate(skillsProvider);
        try {
          await ref.read(skillsProvider.future);
        } catch (_) {}
      },
      child: skillsAsync.when(
        data: (skills) {
          if (skills.isEmpty) {
            return _buildEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: "No Skills Available",
              message: "Connect to Hermes Gateway to load configured skills.",
              showRetry: true,
              onRetry: () => ref.invalidate(skillsProvider),
            );
          }

          final categories = <String>["All"];
          for (final s in skills) {
            final cat = _formatCategory(s.category);
            if (!categories.contains(cat)) categories.add(cat);
          }

          final query = _skillSearchCtrl.text.trim().toLowerCase();
          final filtered = skills.where((s) {
            final matchesQuery = query.isEmpty ||
                s.name.toLowerCase().contains(query) ||
                s.description.toLowerCase().contains(query);
            final matchesCat = _selectedCategory == "All" ||
                _formatCategory(s.category) == _selectedCategory;
            return matchesQuery && matchesCat;
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Search input
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    decoration: NeumorphicDecoration.recessed(radius: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _skillSearchCtrl,
                      style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search ${skills.length} skills...",
                        hintStyle: const TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
                                onPressed: () {
                                  _skillSearchCtrl.clear();
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

              // Categories filter pills
              SliverToBoxAdapter(
                child: Container(
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isSelected = cat == _selectedCategory;
                      final count = cat == "All"
                          ? skills.length
                          : skills.where((s) => _formatCategory(s.category) == cat).length;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: isSelected
                              ? NeumorphicDecoration.recessed(radius: 12)
                              : NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? HermesTokens.accent : HermesTokens.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "$count",
                                style: TextStyle(
                                  color: isSelected ? HermesTokens.accentText : HermesTokens.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                        "${filtered.length} SKILLS",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Tap card for details / markdown",
                        style: TextStyle(fontSize: 10, color: HermesTokens.textMuted),
                      ),
                    ],
                  ),
                ),
              ),

              // Skills list (matches toolset layout)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final s = filtered[index];
                      return _buildInteractiveSkillCard(s);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const CapabilityListSkeleton(),
        error: (e, _) => _buildConnectionFailedState(e.toString(), () => ref.invalidate(skillsProvider)),
      ),
    );
  }

  Widget _buildInteractiveSkillCard(SkillInfo skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: NeumorphicDecoration.raised(radius: 16, distance: 3, blur: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSkillDetail(context, skill),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: NeumorphicDecoration.recessed(radius: 10),
                  child: Icon(
                    _getIconForSkill(skill.name),
                    color: skill.enabled ? HermesTokens.accent : HermesTokens.textMuted,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: skill.enabled ? HermesTokens.textPrimary : HermesTokens.textMuted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: HermesTokens.bgSecondary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: HermesTokens.border),
                            ),
                            child: Text(
                              _formatCategory(skill.category),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: HermesTokens.textMuted,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ExpandableText(
                        text: skill.description.isNotEmpty ? skill.description : "No description provided.",
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch.adaptive(
                  value: skill.enabled,
                  activeThumbColor: HermesTokens.accent,
                  onChanged: (val) async {
                    final conn = ref.read(connectionProvider).valueOrNull;
                    if (conn != null) {
                      await conn.setSkillEnabled(skill.name, val);
                      ref.invalidate(skillsProvider);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSkillDetail(BuildContext context, SkillInfo skill) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: HermesTokens.bgElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HermesTokens.borderBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: NeumorphicDecoration.recessed(radius: 12),
                      child: Icon(_getIconForSkill(skill.name), color: HermesTokens.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: HermesTokens.bgSecondary,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: HermesTokens.border),
                            ),
                            child: Text(
                              _formatCategory(skill.category).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: HermesTokens.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (_, ref, _) {
                        return Switch.adaptive(
                          value: skill.enabled,
                          activeThumbColor: HermesTokens.accent,
                          onChanged: (val) async {
                            final conn = ref.read(connectionProvider).valueOrNull;
                            if (conn != null) {
                              await conn.setSkillEnabled(skill.name, val);
                              ref.invalidate(skillsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  skill.description,
                  style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: HermesTokens.border, height: 1),

              // Markdown Content Viewer
              Expanded(
                child: FutureBuilder<String>(
                  future: ref.read(connectionProvider).valueOrNull?.getSkillContent(skill.name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                      );
                    }
                    final content = snapshot.data ?? "";
                    if (content.isEmpty) {
                      return const Center(
                        child: Text(
                          "No prompt or instructions defined for this skill.",
                          style: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: MarkdownBody(
                        data: content,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13, height: 1.5),
                          h1: const TextStyle(color: HermesTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          h2: const TextStyle(color: HermesTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          h3: const TextStyle(color: HermesTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                          code: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            backgroundColor: Color(0x1F2563EB),
                            color: HermesTokens.accentText,
                            fontSize: 12,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: HermesTokens.bgSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HermesTokens.border),
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
  }

  Widget _buildToolsetsTab(AsyncValue<List<ToolsetInfo>> toolsetsAsync) {
    return RefreshIndicator(
      color: HermesTokens.accent,
      backgroundColor: HermesTokens.bgElevated,
      onRefresh: () async {
        ref.invalidate(toolsetsProvider);
        try {
          await ref.read(toolsetsProvider.future);
        } catch (_) {}
      },
      child: toolsetsAsync.when(
        data: (toolsets) {
          if (toolsets.isEmpty) {
            return _buildEmptyState(
              icon: Icons.construction_outlined,
              title: "No Toolsets Available",
              message: "Hermes Gateway currently has no active toolsets configured.",
              showRetry: true,
              onRetry: () => ref.invalidate(toolsetsProvider),
            );
          }

          final query = _toolsetSearchCtrl.text.trim().toLowerCase();
          final filtered = toolsets.where((t) {
            return query.isEmpty ||
                t.label.toLowerCase().contains(query) ||
                t.description.toLowerCase().contains(query) ||
                t.key.toLowerCase().contains(query);
          }).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    decoration: NeumorphicDecoration.recessed(radius: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _toolsetSearchCtrl,
                      style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search ${toolsets.length} toolsets...",
                        hintStyle: const TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
                                onPressed: () {
                                  _toolsetSearchCtrl.clear();
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
                  child: Text(
                    "${filtered.length} TOOLSETS",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: NeumorphicDecoration.raised(radius: 16, distance: 3, blur: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: NeumorphicDecoration.recessed(radius: 10),
                              child: const Icon(Icons.extension_rounded, color: HermesTokens.accent, size: 19),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.label,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: HermesTokens.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: HermesTokens.bgSecondary,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: HermesTokens.border),
                                        ),
                                        child: Text(
                                          t.key,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: HermesTokens.textMuted,
                                            fontFamily: 'JetBrains Mono',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ExpandableText(
                                    text: t.description,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Switch.adaptive(
                              value: t.enabled,
                              activeThumbColor: HermesTokens.accent,
                              onChanged: (val) async {
                                final conn = ref.read(connectionProvider).valueOrNull;
                                if (conn != null) {
                                  await conn.setToolsetEnabled(t.key, val);
                                  ref.invalidate(toolsetsProvider);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const CapabilityListSkeleton(),
        error: (e, _) => _buildConnectionFailedState(e.toString(), () => ref.invalidate(toolsetsProvider)),
      ),
    );
  }

  Widget _buildMcpTab(
    AsyncValue<List<Map<String, dynamic>>> mcpAsync,
    AsyncValue<List<Map<String, dynamic>>> catalogAsync,
  ) {
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
            return _buildConnectionFailedState(
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
                      style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _mcpTabSegment == 0
                            ? "Search ${servers.length} configured servers..."
                            : "Search catalog of ${catalog.length} MCP tools...",
                        hintStyle: const TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
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
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (_mcpTabSegment == 1)
                        const Text(
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
                              style: const TextStyle(fontSize: 13, color: HermesTokens.textMuted),
                            ),
                            if (query.isEmpty) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () => setState(() => _mcpTabSegment = 1),
                                style: FilledButton.styleFrom(
                                  backgroundColor: HermesTokens.bgSecondary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text("Explore Catalog", style: TextStyle(color: HermesTokens.accent)),
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
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: HermesTokens.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            transport,
                                            style: const TextStyle(
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
                                  child: const Padding(
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
                          style: const TextStyle(fontSize: 13, color: HermesTokens.textMuted),
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
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: HermesTokens.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  transport,
                                                  style: const TextStyle(
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
                                              const Text(
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
                                          child: const Text(
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
          backgroundColor: const Color(0xFFE0E5EC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Install $name",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
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
                  style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Transport: $transport",
                  style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                ),
                if (requiredEnvs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
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
                    Text(
                      e['prompt']?.toString() ?? e['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HermesTokens.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: TextField(
                        controller: controllers[e['name']?.toString() ?? ''],
                        style: const TextStyle(fontSize: 12, color: HermesTokens.textPrimary),
                        decoration: InputDecoration(
                          hintText: e['name']?.toString() ?? 'Value',
                          hintStyle: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
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
        backgroundColor: const Color(0xFFE0E5EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Uninstall $name?",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Text(
          "Are you sure you want to remove the '$name' MCP server from your Hermes profile?",
          style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
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
        backgroundColor: const Color(0xFFE0E5EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Uninstall Plugin",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        content: Text(
          "Are you sure you want to remove the '$name' plugin from your Hermes instance?",
          style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
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
        backgroundColor: const Color(0xFFE0E5EC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.extension_outlined, size: 20, color: HermesTokens.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Install $name",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
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
                      const Text(
                        "REQUIREMENTS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: HermesTokens.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Platform: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
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
                            const Text("Env Vars: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
                            Expanded(
                              child: Text(
                                requiresEnv.join(', '),
                                style: const TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', color: HermesTokens.accentText),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (maintainer.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text("Maintainer: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary)),
                            Text(
                              maintainer,
                              style: const TextStyle(fontSize: 11, color: HermesTokens.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
                if (repo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Source: $repo",
                    style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted, fontFamily: 'JetBrains Mono'),
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
                      style: const TextStyle(fontSize: 11, color: HermesTokens.textSecondary, height: 1.3),
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
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
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

  Widget _buildPluginTab(
    AsyncValue<List<Map<String, dynamic>>> pluginsAsync,
    AsyncValue<List<Map<String, dynamic>>> catalogAsync,
  ) {
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
                      style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _pluginTabSegment == 0
                            ? "Search ${plugins.length} installed plugins..."
                            : "Search catalog of ${catalog.length} plugins...",
                        hintStyle: const TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
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
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (_pluginTabSegment == 1)
                        const Text(
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
                          style: const TextStyle(fontSize: 13, color: HermesTokens.textMuted),
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
                                                  style: const TextStyle(
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
                                                  style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
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
                                      const SizedBox(
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
                                          child: const Padding(
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
                                        side: const BorderSide(color: HermesTokens.accent),
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
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HermesTokens.accent),
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
                          style: const TextStyle(fontSize: 13, color: HermesTokens.textMuted),
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
                            categoryFormatted: _formatCategory((c['category'] ?? '').toString()),
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

  IconData _getIconForSkill(String name) {
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    bool showRetry = false,
    VoidCallback? onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: NeumorphicDecoration.raised(radius: 16),
                  child: Icon(icon, size: 26, color: HermesTokens.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HermesTokens.textMuted,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showRetry && onRetry != null) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionFailedState(String error, VoidCallback onRetry) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: NeumorphicDecoration.raised(radius: 16),
                  child: const Icon(Icons.wifi_off_rounded, size: 26, color: HermesTokens.error),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Connection Failed",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HermesTokens.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: onRetry,
                  child: const Text("Retry", style: TextStyle(color: HermesTokens.accentText)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                              style: const TextStyle(
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
                                style: const TextStyle(
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
                                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: HermesTokens.textSecondary),
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
                              child: const Text(
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
                                style: const TextStyle(fontSize: 8.5, color: HermesTokens.textMuted),
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
                        style: const TextStyle(
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
                              style: const TextStyle(
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
                                    style: const TextStyle(fontSize: 10, color: HermesTokens.textSecondary),
                                  ),
                                ),
                              if (maintainer.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    "Maintainer: $maintainer",
                                    style: const TextStyle(fontSize: 10, color: HermesTokens.textSecondary),
                                  ),
                                ),
                              if (repo.isNotEmpty)
                                Text(
                                  sha.isNotEmpty ? "Source: $repo ($sha)" : "Source: $repo",
                                  style: const TextStyle(fontSize: 10, color: HermesTokens.textMuted, fontFamily: 'JetBrains Mono'),
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
                              style: const TextStyle(
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
                  const SizedBox(
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
