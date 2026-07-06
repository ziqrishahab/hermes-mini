import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";

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
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(skillsProvider);
    final toolsetsAsync = ref.watch(toolsetsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF003F7A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Capabilities",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFECECEC)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: const Color(0xFF003F7A),
                  borderRadius: BorderRadius.circular(6),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF8E8E8E),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(3),
                tabs: const [
                  Tab(text: "Skills"),
                  Tab(text: "MCP Server"),
                  Tab(text: "Plugin"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Skills tab
          _buildList(
            skillsAsync,
            Icons.auto_awesome,
            (item) => _capCard(
              item.name,
              item.description,
              Icons.auto_awesome,
              item.enabled,
              (v) {
                ref.read(connectionProvider).valueOrNull?.setSkillEnabled(item.name, v);
                ref.invalidate(skillsProvider);
              },
            ),
            emptyMsg: "No skills configured.\nConnect to Hermes Gateway to load skills.",
          ),

          // MCP Server tab
          _buildEmpty("MCP Server configuration\ncoming soon."),

          // Plugin tab
          _buildEmpty("Plugin management\ncoming soon."),
        ],
      ),
    );
  }

  Widget _buildList(
    AsyncValue<List<dynamic>> async,
    IconData icon,
    Widget Function(dynamic) builder, {
    String emptyMsg = "No items found.",
  }) {
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E), height: 1.6),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: items.map<Widget>((s) => builder(s)).toList(),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF003F7A)),
      ),
      error: (e, _) => Center(
        child: Text("Failed: $e", style: const TextStyle(color: Color(0xFFEF4444))),
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E8E), height: 1.6),
        ),
      ),
    );
  }

  Widget _capCard(
    String title,
    String desc,
    IconData icon,
    bool enabled,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF003F7A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF003F7A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFECECEC),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: const Color(0xFF003F7A),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
