import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";
import "../../providers/chat_provider.dart";
import "../../theme.dart";
import "../widgets/neumorphic_skeleton.dart";

class ModelConfigScreen extends ConsumerStatefulWidget {
  const ModelConfigScreen({super.key});

  @override
  ConsumerState<ModelConfigScreen> createState() => _ModelConfigScreenState();
}

class _ModelConfigScreenState extends ConsumerState<ModelConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _modelsScrollCtrl = ScrollController();
  String _searchQuery = '';
  String _selectedProvider = 'All';
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        final url = await conn.getConfigValue('custom_provider_url');
        if (mounted && url.isNotEmpty) {
          setState(() {
            _urlCtrl.text = url;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _searchCtrl.dispose();
    _modelsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final conn = ref.read(connectionProvider).valueOrNull;
    final url = _urlCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();

    try {
      if (conn != null) {
        final selectedModel = ref.read(selectedModelProvider);
        if (url.isNotEmpty) {
          await conn.setConfigValue('custom_provider_url', url);
        }
        if (key.isNotEmpty) {
          await conn.setModelProviderKey(selectedModel, 'openrouter', key);
        }
        ref.invalidate(modelsProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Model configuration saved successfully"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(modelsProvider);
    final selected = ref.watch(selectedModelProvider);
    final models = modelsAsync.valueOrNull ?? [];
    final currentConfig = models.where((x) => x.name == selected).firstOrNull;
    final provider = currentConfig?.provider ?? "Default";

    // Extract unique providers for filter chips
    final providerSet = <String>{'All'};
    for (final m in models) {
      final p = m.provider.trim();
      if (p.isNotEmpty) {
        providerSet.add(p);
      }
    }
    final providers = providerSet.toList();

    // Filter models by search query and selected provider
    final query = _searchQuery.trim().toLowerCase();
    final filteredModels = models.where((m) {
      final matchesProvider = _selectedProvider == 'All' ||
          m.provider.toLowerCase() == _selectedProvider.toLowerCase();
      if (!matchesProvider) return false;

      if (query.isEmpty) return true;
      final matchName = m.name.toLowerCase().contains(query);
      final matchModel = m.model.toLowerCase().contains(query);
      final matchProv = m.provider.toLowerCase().contains(query);
      return matchName || matchModel || matchProv;
    }).toList();

    return Scaffold(
      backgroundColor: HermesTokens.bgPrimary,
      appBar: AppBar(
        backgroundColor: HermesTokens.bgPrimary,
        elevation: 0,
        centerTitle: true,
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
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: const Text(
          "Model Configuration",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Active Model Hero Card
              _sectionLabel("ACTIVE MODEL"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      child: const Icon(Icons.psychology_rounded, color: HermesTokens.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Provider: $provider",
                            style: const TextStyle(fontSize: 12, color: HermesTokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: NeumorphicDecoration.recessed(radius: 10),
                      child: const Text(
                        "In Use",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: HermesTokens.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 2. Custom Inference Endpoint (Base URL & API Key)
              _sectionLabel("CUSTOM INFERENCE ENDPOINT"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Base URL",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _urlCtrl,
                        style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "https://openrouter.ai/api/v1",
                          hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "API Key",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: NeumorphicDecoration.recessed(radius: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _apiKeyCtrl,
                              obscureText: _obscureKey,
                              style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "sk-...",
                                hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: HermesTokens.textMuted,
                            ),
                            onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: InkWell(
                        onTap: _saving ? null : _saveConfig,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: NeumorphicDecoration.raised(
                            radius: 14,
                            color: HermesTokens.accent,
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    "Save Endpoint Configuration",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Available Models Catalog
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel("AVAILABLE MODELS"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: NeumorphicDecoration.recessed(radius: 10),
                    child: Text(
                      models.isEmpty
                          ? "0 Models"
                          : (filteredModels.length == models.length
                              ? "${models.length} Models"
                              : "${filteredModels.length} of ${models.length}"),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HermesTokens.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (modelsAsync.isLoading && models.isEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: const ModelListSkeleton(count: 4),
                )
              else if (models.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: const Column(
                    children: [
                      Icon(Icons.dns_outlined, color: HermesTokens.textMuted, size: 36),
                      SizedBox(height: 10),
                      Text(
                        "No models discovered",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Configure your Base URL and API Key above, then tap Save to fetch models.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: HermesTokens.textMuted),
                      ),
                    ],
                  ),
                )
              else ...[
                // Search Field
                Container(
                  decoration: NeumorphicDecoration.recessed(radius: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: HermesTokens.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: HermesTokens.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: "Search model or provider...",
                            hintStyle: TextStyle(color: HermesTokens.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: const Icon(Icons.clear_rounded, size: 18, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Provider Filter Chips (if more than 2 options including "All")
                if (providers.length > 2) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: providers.map((prov) {
                        final isSelected = prov == _selectedProvider;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedProvider = prov),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: isSelected
                                  ? NeumorphicDecoration.raised(
                                      radius: 10,
                                      color: HermesTokens.accent,
                                      distance: 2,
                                      blur: 4,
                                    )
                                  : NeumorphicDecoration.raised(
                                      radius: 10,
                                      distance: 2,
                                      blur: 4,
                                    ),
                              child: Text(
                                prov,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : HermesTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Constrained Scrollable Models Container
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: filteredModels.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 32, color: HermesTokens.textMuted),
                                  const SizedBox(height: 8),
                                  Text(
                                    "No models match \"$_searchQuery\"",
                                    style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchQuery = "";
                                        _selectedProvider = "All";
                                      });
                                    },
                                    child: const Text(
                                      "Reset Filter",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: HermesTokens.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: _modelsScrollCtrl,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _modelsScrollCtrl,
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredModels.length,
                              separatorBuilder: (_, index) => const Divider(height: 1, color: HermesTokens.divider),
                              itemBuilder: (context, i) => _modelSelectTile(filteredModels[i], selected),
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: HermesTokens.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _modelSelectTile(ModelConfig model, String current) {
    final isSelected = model.name == current;
    return InkWell(
      onTap: () async {
        ref.read(selectedModelProvider.notifier).state = model.name;
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          try {
            await conn.setModelEnabled(model.name, true);
            ref.invalidate(modelsProvider);
          } catch (_) {}
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? HermesTokens.accent : HermesTokens.textPrimary,
                    ),
                  ),
                  if (model.provider.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      model.provider,
                      style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: NeumorphicDecoration.circle(color: HermesTokens.accent),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: NeumorphicDecoration.recessed(radius: 10),
              ),
          ],
        ),
      ),
    );
  }
}
