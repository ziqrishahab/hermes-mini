import '../../../../providers/connection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/expandable_text.dart';
import '../../../../theme.dart';
import '../../../widgets/neumorphic_skeleton.dart';
import '../capabilities_providers.dart';
import 'capabilities_common_widgets.dart';

class ToolsetsTab extends ConsumerStatefulWidget {
  const ToolsetsTab({super.key});

  @override
  ConsumerState<ToolsetsTab> createState() => _ToolsetsTabState();
}

class _ToolsetsTabState extends ConsumerState<ToolsetsTab> {
  final _toolsetSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _toolsetSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolsetsAsync = ref.watch(toolsetsProvider);
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
            return CapabilitiesEmptyState(
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
                      style: TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search ${toolsets.length} toolsets...",
                        hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: HermesTokens.textMuted, size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 16, color: HermesTokens.textMuted),
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
                    style: TextStyle(
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
                              child: Icon(Icons.extension_rounded, color: HermesTokens.accent, size: 19),
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
                                          style: TextStyle(
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
        error: (e, _) => CapabilitiesConnectionFailedState(e.toString(), () => ref.invalidate(toolsetsProvider)),
      ),
    );
  }


}
