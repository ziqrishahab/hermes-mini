import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../theme.dart";
import "capabilities/widgets/skills_tab.dart";
import "capabilities/widgets/toolsets_tab.dart";
import "capabilities/widgets/mcp_tab.dart";
import "capabilities/widgets/plugins_tab.dart";

export "capabilities/capabilities_providers.dart";

class CapabilitiesScreen extends ConsumerStatefulWidget {
  const CapabilitiesScreen({super.key});

  @override
  ConsumerState<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends ConsumerState<CapabilitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: HermesTokens.textPrimary, size: 16),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              )
            : null,
        title: Text(
          "Capabilities",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
                child: IconButton(
                  tooltip: "Explore Registry",
                  icon: Icon(Icons.explore_outlined, color: HermesTokens.accent, size: 20),
                  onPressed: () => context.push('/discover'),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
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
                indicator: NeumorphicDecoration.switcherThumb(radius: 10),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: HermesTokens.accent,
                unselectedLabelColor: HermesTokens.textMuted,
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
        children: const [
          SkillsTab(),
          ToolsetsTab(),
          McpTab(),
          PluginsTab(),
        ],
      ),
    );
  }
}
