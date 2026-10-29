import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/registry_item.dart';
import '../../providers/connection_provider.dart';
import '../../services/registry_service.dart';
import '../../theme.dart';

class RegistryDiscoverScreen extends ConsumerStatefulWidget {
  const RegistryDiscoverScreen({super.key});

  @override
  ConsumerState<RegistryDiscoverScreen> createState() =>
      _RegistryDiscoverScreenState();
}

class _RegistryDiscoverScreenState
    extends ConsumerState<RegistryDiscoverScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedType = 'all'; // 'all', 'skill', 'mcp'
  String _searchQuery = '';
  List<RegistryItem> _items = [];
  bool _loading = true;
  String? _error;
  final Set<String> _installingIds = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await RegistryService.fetchCatalog(forceRefresh: refresh);
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _installItem(RegistryItem item) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      _showSnackBar("Not connected to Hermes instance", isError: true);
      return;
    }

    setState(() {
      _installingIds.add(item.id);
    });

    try {
      final ok = await RegistryService.installItem(conn, item);
      if (mounted) {
        if (ok) {
          _showSnackBar("Installed '${item.name}' successfully.");
        } else {
          _showSnackBar("Installation failed. Check instance logs.",
              isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Install error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _installingIds.remove(item.id);
        });
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError ? HermesTokens.error : HermesTokens.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<RegistryItem> get _filteredItems {
    return _items.where((item) {
      if (_selectedType != 'all' && item.type != _selectedType) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          (item.author != null && item.author!.toLowerCase().contains(q)) ||
          item.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: HermesTokens.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Community Registry",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: HermesTokens.textPrimary),
            tooltip: "Refresh Catalog",
            onPressed: () => _loadCatalog(refresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(
                  color: HermesTokens.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: "Search skills, MCP servers, tools...",
                  hintStyle: GoogleFonts.inter(
                    color: HermesTokens.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: HermesTokens.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            color: HermesTokens.textMuted,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: HermesTokens.bgElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                    borderSide: BorderSide(color: HermesTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                    borderSide: BorderSide(color: HermesTokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                    borderSide: BorderSide(color: HermesTokens.accent),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildTypeChip('All Items', 'all'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Skills', 'skill'),
                  const SizedBox(width: 8),
                  _buildTypeChip('MCP Servers', 'mcp'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 40,
                                  color: HermesTokens.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Failed to load registry",
                                  style: GoogleFonts.inter(
                                    color: HermesTokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.tonal(
                                  onPressed: () => _loadCatalog(refresh: true),
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                "No items found matching criteria",
                                style: GoogleFonts.inter(
                                  color: HermesTokens.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final item = filtered[idx];
                                final isInstalling =
                                    _installingIds.contains(item.id);
                                return _buildItemCard(item, isInstalling);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String typeKey) {
    final isSelected = (_selectedType == typeKey);
    return InkWell(
      onTap: () {
        setState(() => _selectedType = typeKey);
      },
      borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? HermesTokens.accent : HermesTokens.bgElevated,
          borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
          border: Border.all(
            color: isSelected ? HermesTokens.accent : HermesTokens.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : HermesTokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(RegistryItem item, bool isInstalling) {
    final isSkill = (item.type == 'skill');

    return Container(
      decoration: BoxDecoration(
        color: HermesTokens.bgElevated,
        borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
        border: Border.all(color: HermesTokens.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HermesTokens.bgPrimary,
                  borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                  border: Border.all(color: HermesTokens.borderBright),
                ),
                child: Icon(
                  isSkill ? Icons.bolt_outlined : Icons.extension_outlined,
                  size: 20,
                  color: isSkill ? Colors.amber[600] : HermesTokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: GoogleFonts.inter(
                              color: HermesTokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HermesTokens.bgPrimary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: HermesTokens.border),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.author != null && item.author!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "by ${item.author}",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: HermesTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: HermesTokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.category != null && item.category!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HermesTokens.bgPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.category!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: HermesTokens.textMuted,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HermesTokens.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HermesTokens.radiusSm),
                  ),
                ),
                onPressed: isInstalling ? null : () => _installItem(item),
                child: isInstalling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            "Install",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
