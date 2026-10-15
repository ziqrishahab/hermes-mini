import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/connection_provider.dart";
import "../../theme.dart";
import "../widgets/neumorphic_skeleton.dart";

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _achievements = [];
  int _unlockedCount = 0;
  int _totalCount = 0;
  bool _isOfflinePreview = false;
  String _selectedCategory = "All";
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  static const List<String> _categories = [
    "All",
    "Debugging Chaos",
    "Vibe Coding",
    "Hermes Native",
    "Research/Web",
    "Tool Mastery",
    "Model Lore",
  ];

  static final List<Map<String, dynamic>> _defaultCatalog = [
    {
      "id": "first_signal",
      "name": "First Signal",
      "description": "Establish connection to Hermes remote gateway.",
      "category": "Hermes Native",
      "unlocked": true,
      "unlocked_tier": 1,
      "secret": false,
      "progress": 1,
      "target": 1,
    },
    {
      "id": "rubber_duck",
      "name": "Rubber Duck Master",
      "description": "Execute runtime debugging cycle with zero crashes.",
      "category": "Debugging Chaos",
      "unlocked": true,
      "unlocked_tier": 2,
      "secret": false,
      "progress": 3,
      "target": 5,
    },
    {
      "id": "one_shot",
      "name": "One Shot Wonder",
      "description": "Resolve an agent goal in a single continuous prompt.",
      "category": "Vibe Coding",
      "unlocked": false,
      "unlocked_tier": 0,
      "secret": false,
      "progress": 0,
      "target": 1,
    },
    {
      "id": "tool_synthesizer",
      "name": "Tool Synthesizer",
      "description": "Invoke 25 tool calls across MCP servers.",
      "category": "Tool Mastery",
      "unlocked": true,
      "unlocked_tier": 3,
      "secret": false,
      "progress": 18,
      "target": 25,
    },
    {
      "id": "memory_palace",
      "name": "Memory Weaver",
      "description": "Store 50 key-value memories in vector session state.",
      "category": "Hermes Native",
      "unlocked": false,
      "unlocked_tier": 0,
      "secret": false,
      "progress": 12,
      "target": 50,
    },
    {
      "id": "deep_search",
      "name": "Web Explorer",
      "description": "Perform comprehensive web searches and synthesize sources.",
      "category": "Research/Web",
      "unlocked": true,
      "unlocked_tier": 1,
      "secret": false,
      "progress": 5,
      "target": 10,
    },
    {
      "id": "context_overload",
      "name": "Context Whale",
      "description": "Fill model context past 64,000 active tokens.",
      "category": "Model Lore",
      "unlocked": false,
      "unlocked_tier": 0,
      "secret": false,
      "progress": 32000,
      "target": 64000,
    },
    {
      "id": "secret_olympian",
      "name": "Olympian Architect",
      "description": "Reach Tier 5 Olympian mastery across all system skills.",
      "category": "Hermes Native",
      "unlocked": false,
      "unlocked_tier": 0,
      "secret": true,
      "progress": 0,
      "target": 5,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _fetchAchievements();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAchievements() async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      if (mounted) {
        setState(() {
          _achievements = _defaultCatalog;
          _unlockedCount = _defaultCatalog.where((a) => a["unlocked"] == true).length;
          _totalCount = _defaultCatalog.length;
          _isOfflinePreview = true;
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? res = await conn.getPluginApi("hermes-achievements", "achievements");
      res ??= await conn.getPluginApi("achievements", "achievements");
      res ??= await conn.getPluginApi("hermes-achievements", "list");
      res ??= await conn.getPluginApi("achievements", "list");
      res ??= await conn.getPluginApi("hermes-achievements", "");
      res ??= await conn.getPluginApi("achievements", "");

      List<dynamic>? rawList;
      if (res != null) {
        if (res["achievements"] is List) {
          rawList = res["achievements"] as List;
        } else if (res["items"] is List) {
          rawList = res["items"] as List;
        } else if (res["data"] is List) {
          rawList = res["data"] as List;
        } else if (res["list"] is List) {
          rawList = res["list"] as List;
        }
      }

      if (rawList != null && rawList.isNotEmpty) {
        final list = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
        if (mounted) {
          setState(() {
            _achievements = list;
            _unlockedCount = int.tryParse(res?["unlocked_count"]?.toString() ?? "") ??
                list.where((a) => a["unlocked"] == true || a["is_unlocked"] == true).length;
            _totalCount = int.tryParse(res?["total_count"]?.toString() ?? "") ?? list.length;
            _isOfflinePreview = false;
            _loading = false;
          });
        }
      } else {
        // Fallback to standard Hermes milestone catalog in preview mode
        if (mounted) {
          setState(() {
            _achievements = _defaultCatalog;
            _unlockedCount = _defaultCatalog.where((a) => a["unlocked"] == true).length;
            _totalCount = _defaultCatalog.length;
            _isOfflinePreview = true;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _achievements = _defaultCatalog;
          _unlockedCount = _defaultCatalog.where((a) => a["unlocked"] == true).length;
          _totalCount = _defaultCatalog.length;
          _isOfflinePreview = true;
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAchievements {
    return _achievements.where((ach) {
      final cat = ach["category"]?.toString() ?? "General";
      if (_selectedCategory != "All" && cat.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final name = ach["name"]?.toString().toLowerCase() ?? "";
        final desc = ach["description"]?.toString().toLowerCase() ?? "";
        return name.contains(_searchQuery) || desc.contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case "debugging chaos":
        return Icons.pest_control_outlined;
      case "vibe coding":
        return Icons.auto_awesome_outlined;
      case "hermes native":
        return Icons.terminal_rounded;
      case "research/web":
        return Icons.travel_explore_rounded;
      case "tool mastery":
        return Icons.construction_rounded;
      case "model lore":
        return Icons.psychology_outlined;
      default:
        return Icons.star_border_rounded;
    }
  }

  String _getTierName(int tierIndex) {
    const names = ["None", "Copper", "Silver", "Gold", "Diamond", "Olympian"];
    if (tierIndex >= 0 && tierIndex < names.length) {
      return names[tierIndex];
    }
    return "Tier $tierIndex";
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAchievements;
    final progressFraction = _totalCount > 0 ? (_unlockedCount / _totalCount).clamp(0.0, 1.0) : 0.0;
    final progressPct = (progressFraction * 100).toInt();

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
              child: IconButton(
                tooltip: "Back",
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: const Text(
          "Achievements",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HermesTokens.textPrimary),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                child: IconButton(
                  tooltip: "Refresh achievements",
                  icon: const Icon(Icons.refresh_rounded, color: HermesTokens.textSecondary, size: 18),
                  onPressed: _fetchAchievements,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const AchievementListSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: NeumorphicDecoration.raised(radius: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: NeumorphicDecoration.recessed(radius: 14),
                            child: const Icon(Icons.error_outline_rounded, size: 24, color: HermesTokens.error),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: HermesTokens.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _fetchAchievements,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              decoration: NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4),
                              child: const Text(
                                "Retry",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HermesTokens.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAchievements,
                  color: HermesTokens.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_isOfflinePreview) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: NeumorphicDecoration.recessed(radius: 12),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: HermesTokens.accent),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Showing standard Hermes achievements (Catalog preview). Install hermes-achievements on your host to sync live telemetry.",
                                  style: TextStyle(fontSize: 11, color: HermesTokens.textMuted, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Overview Progress Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: NeumorphicDecoration.raised(radius: 18, distance: 3, blur: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Overall Completion",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: HermesTokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$_unlockedCount of $_totalCount milestones unlocked",
                                      style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                                    ),
                                  ],
                                ),
                                Text(
                                  "$progressPct%",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: HermesTokens.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Progress bar
                            Container(
                              height: 8,
                              decoration: NeumorphicDecoration.recessed(radius: 4),
                              clipBehavior: Clip.antiAlias,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressFraction,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: HermesTokens.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      Container(
                        decoration: NeumorphicDecoration.recessed(radius: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 13, color: HermesTokens.textPrimary),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Search milestones or categories...",
                            hintStyle: const TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                            icon: const Icon(Icons.search_rounded, size: 18, color: HermesTokens.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: HermesTokens.textMuted),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () => setState(() => _selectedCategory = cat),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: isSelected
                                      ? NeumorphicDecoration.raised(radius: 10, distance: 2, blur: 4)
                                      : NeumorphicDecoration.recessed(radius: 10),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? HermesTokens.accent : HermesTokens.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List of Achievements
                      if (filtered.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: NeumorphicDecoration.recessed(radius: 12),
                                  child: const Icon(Icons.filter_list_off_rounded, size: 20, color: HermesTokens.textMuted),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "No achievements found matching filter",
                                  style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map((ach) {
                          final isUnlocked = ach["unlocked"] == true;
                          final isSecret = ach["secret"] == true;
                          final name = isSecret && !isUnlocked ? "Secret Milestone" : (ach["name"]?.toString() ?? "Achievement");
                          final desc = isSecret && !isUnlocked
                              ? "Details hidden until discovered during agent sessions."
                              : (ach["description"]?.toString() ?? "");
                          final category = ach["category"]?.toString() ?? "General";
                          final tierVal = int.tryParse(ach["unlocked_tier"]?.toString() ?? "0") ?? (isUnlocked ? 1 : 0);
                          final tierName = _getTierName(tierVal);

                          // Progress metrics if available
                          final progressCurrent = ach["progress_current"];
                          final progressTarget = ach["progress_target"];
                          final hasProgress = !isUnlocked && progressCurrent is num && progressTarget is num && progressTarget > 0;
                          final fraction = hasProgress ? (progressCurrent / progressTarget).clamp(0.0, 1.0) : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: NeumorphicDecoration.raised(
                              radius: 16,
                              distance: isUnlocked ? 2.5 : 1.5,
                              blur: isUnlocked ? 5 : 3,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: isUnlocked
                                      ? NeumorphicDecoration.raised(radius: 12, distance: 2, blur: 4)
                                      : NeumorphicDecoration.recessed(radius: 12),
                                  child: Icon(
                                    isSecret && !isUnlocked ? Icons.lock_outline_rounded : _getIconForCategory(category),
                                    size: 20,
                                    color: isUnlocked ? HermesTokens.accent : HermesTokens.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Texts
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isUnlocked ? HermesTokens.textPrimary : HermesTokens.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isUnlocked)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: NeumorphicDecoration.recessed(radius: 6),
                                              child: Text(
                                                tierName,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: HermesTokens.accent,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              "Locked",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: HermesTokens.textMuted.withValues(alpha: 0.8),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: HermesTokens.textMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            category,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: HermesTokens.textMuted),
                                          ),
                                          if (hasProgress) ...[
                                            const Spacer(),
                                            Text(
                                              "$progressCurrent / $progressTarget",
                                              style: const TextStyle(fontSize: 10, color: HermesTokens.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (hasProgress) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          height: 4,
                                          decoration: NeumorphicDecoration.recessed(radius: 2),
                                          clipBehavior: Clip.antiAlias,
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: fraction,
                                            child: Container(
                                              color: HermesTokens.accent.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
