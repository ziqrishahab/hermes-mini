import '../../../../providers/connection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/hermes_connection.dart';
import '../../../../theme.dart';
import '../../../widgets/expandable_text.dart';
import '../../../widgets/neumorphic_skeleton.dart';
import '../capabilities_providers.dart';
import 'capabilities_common_widgets.dart';

class SkillsTab extends ConsumerStatefulWidget {
  const SkillsTab({super.key});

  @override
  ConsumerState<SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<SkillsTab> {
  final _skillSearchCtrl = TextEditingController();
  String _selectedCategory = "All";

  @override
  void dispose() {
    _skillSearchCtrl.dispose();
    super.dispose();
  }

  String formatCapabilityCategory(String cat) {
    if (cat.isEmpty) return "General";
    return cat.replaceAll("-", " ").split(" ").map((w) {
      if (w.isEmpty) return "";
      return w[0].toUpperCase() + w.substring(1);
    }).join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);
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
            return CapabilitiesEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: "No Skills Available",
              message: "Connect to Hermes Gateway to load configured skills.",
              showRetry: true,
              onRetry: () => ref.invalidate(skillsProvider),
            );
          }

          final categories = <String>["All"];
          for (final s in skills) {
            final cat = formatCapabilityCategory(s.category);
            if (!categories.contains(cat)) categories.add(cat);
          }

          final query = _skillSearchCtrl.text.trim().toLowerCase();
          final filtered = skills.where((s) {
            final matchesQuery = query.isEmpty ||
                s.name.toLowerCase().contains(query) ||
                s.description.toLowerCase().contains(query);
            final matchesCat = _selectedCategory == "All" ||
                formatCapabilityCategory(s.category) == _selectedCategory;
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
                      style: TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search ${skills.length} skills...",
                        hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
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
                          : skills.where((s) => formatCapabilityCategory(s.category) == cat).length;

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
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
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
        error: (e, _) => CapabilitiesConnectionFailedState(e.toString(), () => ref.invalidate(skillsProvider)),
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
                    getIconForCapabilitySkill(skill.name),
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
                              formatCapabilityCategory(skill.category),
                              style: TextStyle(
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
          decoration: BoxDecoration(
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
                      child: Icon(getIconForCapabilitySkill(skill.name), color: HermesTokens.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.name,
                            style: TextStyle(
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
                              formatCapabilityCategory(skill.category).toUpperCase(),
                              style: TextStyle(
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
                  style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: HermesTokens.border, height: 1),

              // Markdown Content Viewer
              Expanded(
                child: FutureBuilder<String>(
                  future: ref.read(connectionProvider).valueOrNull?.getSkillContent(skill.name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: HermesTokens.accent),
                      );
                    }
                    final content = snapshot.data ?? "";
                    if (content.isEmpty) {
                      return Center(
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
                          p: TextStyle(color: HermesTokens.textPrimary, fontSize: 13, height: 1.5),
                          h1: TextStyle(color: HermesTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          h2: TextStyle(color: HermesTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          h3: TextStyle(color: HermesTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                          code: TextStyle(
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


}
