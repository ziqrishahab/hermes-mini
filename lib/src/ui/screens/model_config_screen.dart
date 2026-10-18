import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../services/hermes_connection.dart";
import "../../providers/connection_provider.dart";
import "../../providers/chat_provider.dart";
import "../../theme.dart";
import "../widgets/hermes_toast.dart";
import "../widgets/neumorphic_skeleton.dart";

/// Model profile data for registered inference providers
class SavedProviderProfile {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final int lastUsedEpoch;

  SavedProviderProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.lastUsedEpoch,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'lastUsedEpoch': lastUsedEpoch,
      };

  factory SavedProviderProfile.fromJson(Map<String, dynamic> json) =>
      SavedProviderProfile(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        baseUrl: json['baseUrl']?.toString() ?? '',
        apiKey: json['apiKey']?.toString() ?? '',
        lastUsedEpoch: json['lastUsedEpoch'] is int ? json['lastUsedEpoch'] : 0,
      );

  static String guessProviderName(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('openrouter')) return 'OpenRouter';
    if (lower.contains('anthropic')) return 'Anthropic';
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        final parts = uri.host.split('.');
        if (parts.length >= 2) {
          final domainName = (parts.length > 2 && parts[0] != 'www') ? parts[parts.length - 2] : parts[0];
          return domainName.isNotEmpty
              ? (domainName[0].toUpperCase() + domainName.substring(1))
              : uri.host;
        }
        return uri.host;
      }
    } catch (_) {}
    return 'Custom';
  }
}

class ModelConfigScreen extends ConsumerStatefulWidget {
  const ModelConfigScreen({super.key});

  @override
  ConsumerState<ModelConfigScreen> createState() => _ModelConfigScreenState();
}

class _ModelConfigScreenState extends ConsumerState<ModelConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _modelsScrollCtrl = ScrollController();

  String _searchQuery = '';
  String _selectedFamilyFilter = 'All';
  bool _obscureKey = true;
  bool _saving = false;

  List<SavedProviderProfile> _savedProviders = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_inference_base_url') ?? '';
      final savedKey = prefs.getString('custom_inference_api_key') ?? '';
      if (mounted) {
        if (savedUrl.isNotEmpty) _urlCtrl.text = savedUrl;
        if (savedKey.isNotEmpty) _apiKeyCtrl.text = savedKey;
      }

      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        final info = await conn.getModelInfo();
        if (mounted && info.isNotEmpty) {
          final bUrl = info['base_url']?.toString() ?? '';
          if (bUrl.isNotEmpty && _urlCtrl.text.isEmpty) {
            _urlCtrl.text = bUrl;
          }
        }
        if (_urlCtrl.text.isEmpty) {
          final url = await conn.getConfigValue('custom_provider_url');
          if (mounted && url.isNotEmpty) {
            _urlCtrl.text = url;
          }
        }
        if (_urlCtrl.text.isEmpty || _apiKeyCtrl.text.isEmpty) {
          final env = await conn.readEnv();
          if (mounted) {
            if (_urlCtrl.text.isEmpty) {
              final envUrl = env['CUSTOM_BASE_URL'] ??
                  env['DEEPSEEK_BASE_URL'] ??
                  env['OPENAI_BASE_URL'];
              if (envUrl != null && envUrl.isNotEmpty) _urlCtrl.text = envUrl;
            }
            if (_apiKeyCtrl.text.isEmpty) {
              final envKey = env['CUSTOM_API_KEY'] ??
                  env['DEEPSEEK_API_KEY'] ??
                  env['OPENAI_API_KEY'];
              if (envKey != null && envKey.isNotEmpty) _apiKeyCtrl.text = envKey;
            }
          }
        }
      }

      await _loadSavedProviders(prefs, _urlCtrl.text.trim(), _apiKeyCtrl.text.trim());
    } catch (_) {}
  }

  Future<void> _loadSavedProviders(
      SharedPreferences prefs, String currentUrl, String currentKey) async {
    final raw = prefs.getString('saved_inference_providers');
    List<SavedProviderProfile> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded
            .map((j) => SavedProviderProfile.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Auto-seed current configuration if not already registered
    if (currentUrl.isNotEmpty) {
      final cleanUrl = currentUrl.trim();
      final cleanKey = currentKey.trim();
      final existingIdx = list.indexWhere(
          (p) => p.baseUrl.trim().toLowerCase() == cleanUrl.toLowerCase());
      if (existingIdx == -1) {
        list.insert(
          0,
          SavedProviderProfile(
            id: 'seed_${DateTime.now().millisecondsSinceEpoch}',
            name: SavedProviderProfile.guessProviderName(cleanUrl),
            baseUrl: cleanUrl,
            apiKey: cleanKey,
            lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        final encoded = jsonEncode(list.map((p) => p.toJson()).toList());
        await prefs.setString('saved_inference_providers', encoded);
      }
    }

    if (mounted) {
      setState(() {
        _savedProviders = list;
      });
    }
  }

  Future<void> _saveProviderProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_savedProviders.map((p) => p.toJson()).toList());
    await prefs.setString('saved_inference_providers', encoded);
  }

  Future<void> _selectProvider(SavedProviderProfile profile) async {
    if (_saving) return;
    HapticFeedback.selectionClick();

    setState(() {
      _saving = true;
      _nameCtrl.text = profile.name;
      _urlCtrl.text = profile.baseUrl;
      _apiKeyCtrl.text = profile.apiKey;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_inference_base_url', profile.baseUrl);
      await prefs.setString('custom_inference_api_key', profile.apiKey);
      await prefs.remove('active_selected_model');

      final idx = _savedProviders.indexWhere((x) => x.id == profile.id);
      if (idx != -1) {
        _savedProviders[idx] = SavedProviderProfile(
          id: profile.id,
          name: profile.name,
          baseUrl: profile.baseUrl,
          apiKey: profile.apiKey,
          lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await _saveProviderProfiles();
      }

      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        await conn.setCustomInferenceEndpoint(
          baseUrl: profile.baseUrl,
          apiKey: profile.apiKey,
        );
        ref.invalidate(modelsProvider);
        await ref.read(modelsProvider.future);
      }

      final fetchErr = conn?.lastModelFetchError;
      if (mounted) {
        if (fetchErr != null && fetchErr.isNotEmpty) {
          HermesToast.show(
            context,
            message: "Switched to ${profile.name}, but provider error: $fetchErr",
            type: HermesToastType.error,
          );
        } else {
          HermesToast.show(
            context,
            message: "Switched to ${profile.name}",
            type: HermesToastType.info,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        HermesToast.show(
          context,
          message: "Failed to switch: $e",
          type: HermesToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteProvider(SavedProviderProfile profile) async {
    setState(() {
      _savedProviders.removeWhere((x) => x.id == profile.id);
    });
    await _saveProviderProfiles();
    if (mounted) {
      HermesToast.show(
        context,
        message: "Removed ${profile.name}",
        type: HermesToastType.info,
      );
    }
  }

  void _confirmDeleteProvider(SavedProviderProfile prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Remove ${prov.name}?",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        content: Text(
          "Are you sure you want to remove this provider preset (${prov.baseUrl})?",
          style: const TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProvider(prov);
            },
            child: const Text(
              "Remove",
              style: TextStyle(color: HermesTokens.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _searchCtrl.dispose();
    _modelsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final conn = ref.read(connectionProvider).valueOrNull;
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();

    try {
      if (conn != null) {
        if (url.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_inference_base_url', url);
          if (key.isNotEmpty) {
            await prefs.setString('custom_inference_api_key', key);
          }

          // Auto-register / update into saved providers list
          final cleanUrl = url.trim();
          final cleanKey = key.trim();
          final resolvedName = name.isNotEmpty
              ? name
              : SavedProviderProfile.guessProviderName(cleanUrl);

          final existingIdx = _savedProviders.indexWhere(
              (p) => p.baseUrl.trim().toLowerCase() == cleanUrl.toLowerCase());
          if (existingIdx != -1) {
            _savedProviders[existingIdx] = SavedProviderProfile(
              id: _savedProviders[existingIdx].id,
              name: name.isNotEmpty ? name : _savedProviders[existingIdx].name,
              baseUrl: cleanUrl,
              apiKey: cleanKey,
              lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
            );
          } else {
            _savedProviders.insert(
              0,
              SavedProviderProfile(
                id: 'prov_${DateTime.now().millisecondsSinceEpoch}',
                name: resolvedName,
                baseUrl: cleanUrl,
                apiKey: cleanKey,
                lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
          await _saveProviderProfiles();

          await conn.setCustomInferenceEndpoint(
            baseUrl: url,
            apiKey: key,
          );
        } else if (key.isNotEmpty) {
          final selectedModel = ref.read(selectedModelProvider);
          await conn.setModelProviderKey(selectedModel, 'custom', key);
        }

        ref.invalidate(modelsProvider);
        await ref.read(modelsProvider.future);

        final fetchErr = conn.lastModelFetchError;
        if (mounted) {
          if (fetchErr != null && fetchErr.isNotEmpty) {
            HermesToast.show(
              context,
              message: "Configuration saved, but provider returned: $fetchErr",
              type: HermesToastType.error,
            );
          } else {
            HermesToast.show(
              context,
              message: "Configuration saved and models fetched",
              type: HermesToastType.info,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        HermesToast.show(
          context,
          message: "Failed to save: $e",
          type: HermesToastType.error,
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

    // 1. Dynamic Model Family Detection
    final availableFilters = <String>['All'];
    final hasFree = models.any((m) =>
        m.name.toLowerCase().contains(':free') ||
        m.name.toLowerCase().contains('free'));
    if (hasFree) availableFilters.add('Free');

    final detectedFamilies = <String>{};
    for (final m in models) {
      final l = m.name.toLowerCase();
      final p = m.provider.toLowerCase();
      if (l.contains('gemini') || l.contains('google') || p.contains('google')) {
        detectedFamilies.add('Gemini');
      } else if (l.contains('gpt') || l.contains('openai') || p.contains('openai')) {
        detectedFamilies.add('GPT');
      } else if (l.contains('qwen') || l.contains('alibaba')) {
        detectedFamilies.add('Qwen');
      } else if (l.contains('deepseek')) {
        detectedFamilies.add('DeepSeek');
      } else if (l.contains('claude') || l.contains('anthropic') || p.contains('anthropic')) {
        detectedFamilies.add('Claude');
      } else if (l.contains('llama') || l.contains('meta')) {
        detectedFamilies.add('Llama');
      } else if (l.contains('mistral')) {
        detectedFamilies.add('Mistral');
      } else if (l.contains('grok') || l.contains('xai')) {
        detectedFamilies.add('Grok');
      }
    }
    availableFilters.addAll(detectedFamilies);

    // 2. Filter models by family and search query
    final query = _searchQuery.trim().toLowerCase();
    final filteredModels = models.where((m) {
      final l = m.name.toLowerCase();
      final p = m.provider.toLowerCase();

      if (_selectedFamilyFilter == 'Free') {
        if (!l.contains(':free') && !l.contains('free')) return false;
      } else if (_selectedFamilyFilter == 'Gemini') {
        if (!l.contains('gemini') && !l.contains('google') && !p.contains('google')) return false;
      } else if (_selectedFamilyFilter == 'GPT') {
        if (!l.contains('gpt') && !l.contains('openai') && !p.contains('openai')) return false;
      } else if (_selectedFamilyFilter == 'Qwen') {
        if (!l.contains('qwen') && !l.contains('alibaba')) return false;
      } else if (_selectedFamilyFilter == 'DeepSeek') {
        if (!l.contains('deepseek')) return false;
      } else if (_selectedFamilyFilter == 'Claude') {
        if (!l.contains('claude') && !l.contains('anthropic') && !p.contains('anthropic')) return false;
      } else if (_selectedFamilyFilter == 'Llama') {
        if (!l.contains('llama') && !l.contains('meta')) return false;
      } else if (_selectedFamilyFilter == 'Mistral') {
        if (!l.contains('mistral')) return false;
      } else if (_selectedFamilyFilter == 'Grok') {
        if (!l.contains('grok') && !l.contains('xai')) return false;
      }

      if (query.isNotEmpty) {
        final matchName = l.contains(query);
        final matchModel = m.model.toLowerCase().contains(query);
        final matchProv = p.contains(query);
        return matchName || matchModel || matchProv;
      }
      return true;
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: HermesTokens.textPrimary, size: 16),
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
                      child: const Icon(Icons.psychology_rounded,
                          color: HermesTokens.accent, size: 24),
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
                            style: const TextStyle(
                                fontSize: 12, color: HermesTokens.textSecondary),
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

              // 2. Custom Inference Endpoint & Registered Providers
              _sectionLabel("CUSTOM INFERENCE ENDPOINT"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Registered Providers Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "REGISTERED PROVIDERS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: HermesTokens.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_savedProviders.isNotEmpty)
                          Text(
                            "${_savedProviders.length} saved",
                            style: const TextStyle(
                              fontSize: 11,
                              color: HermesTokens.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _savedProviders.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          if (idx == _savedProviders.length) {
                            // + New Provider button
                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _nameCtrl.clear();
                                  _urlCtrl.clear();
                                  _apiKeyCtrl.clear();
                                });
                                HermesToast.show(
                                  context,
                                  message: "Enter URL and API Key for new provider",
                                  type: HermesToastType.info,
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: NeumorphicDecoration.recessed(radius: 14),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 16, color: HermesTokens.accent),
                                    SizedBox(width: 4),
                                    Text(
                                      "New",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: HermesTokens.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final prov = _savedProviders[idx];
                          final isCurrent = _urlCtrl.text.trim().toLowerCase() ==
                              prov.baseUrl.trim().toLowerCase();

                          return InkWell(
                            onTap: () => _selectProvider(prov),
                            onLongPress: () => _confirmDeleteProvider(prov),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: isCurrent
                                  ? NeumorphicDecoration.raised(
                                      radius: 14,
                                      color: HermesTokens.accent,
                                    )
                                  : NeumorphicDecoration.raised(radius: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCurrent
                                        ? Icons.check_circle_rounded
                                        : Icons.dns_outlined,
                                    size: 14,
                                    color: isCurrent
                                        ? Colors.white
                                        : HermesTokens.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    prov.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isCurrent
                                          ? Colors.white
                                          : HermesTokens.textPrimary,
                                    ),
                                  ),
                                  if (!isCurrent) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _confirmDeleteProvider(prov),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 13,
                                        color: HermesTokens.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      "Provider Name (Optional)",
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
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "e.g. OpenRouter, My LLM (Auto-detected if blank)",
                          hintStyle: TextStyle(
                              color: HermesTokens.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

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
                        style: const TextStyle(
                            color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "https://openrouter.ai/api/v1 or custom URL",
                          hintStyle: TextStyle(
                              color: HermesTokens.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
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
                              style: const TextStyle(
                                  color: HermesTokens.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "sk-...",
                                hintStyle: TextStyle(
                                    color: HermesTokens.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _obscureKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: HermesTokens.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscureKey = !_obscureKey),
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
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

              // 3. Available Models Catalog with Filter Pills
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
              if (ref.watch(connectionProvider).valueOrNull?.lastModelFetchError != null &&
                  ref.watch(connectionProvider).valueOrNull!.lastModelFetchError!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: HermesTokens.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HermesTokens.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: HermesTokens.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.watch(connectionProvider).valueOrNull!.lastModelFetchError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HermesTokens.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

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
                      const Icon(Icons.search_rounded,
                          size: 18, color: HermesTokens.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(
                              color: HermesTokens.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: "Search model or provider...",
                            hintStyle: TextStyle(
                                color: HermesTokens.textMuted, fontSize: 13),
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
                          child: const Icon(Icons.clear_rounded,
                              size: 18, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Family Filter Pills
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: availableFilters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, chipIdx) {
                      final chip = availableFilters[chipIdx];
                      final isChipSelected = _selectedFamilyFilter == chip;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFamilyFilter = chip);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isChipSelected
                                ? HermesTokens.accent
                                : HermesTokens.bgSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isChipSelected
                                  ? HermesTokens.accent
                                  : HermesTokens.borderBright
                                      .withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                            boxShadow: isChipSelected
                                ? [
                                    BoxShadow(
                                      color: HermesTokens.accent
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isChipSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isChipSelected
                                    ? Colors.white
                                    : HermesTokens.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Constrained Scrollable Models Container
                Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: filteredModels.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 36, horizontal: 16),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 32, color: HermesTokens.textMuted),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedFamilyFilter != 'All'
                                        ? "No models match filter \"$_selectedFamilyFilter\""
                                        : "No models match \"$_searchQuery\"",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: HermesTokens.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchQuery = "";
                                        _selectedFamilyFilter = 'All';
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
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 1, color: HermesTokens.divider),
                              itemBuilder: (context, i) =>
                                  _modelSelectTile(filteredModels[i], selected),
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
    final cleanName = _cleanFormat(model.name);
    final slashIdx = model.name.indexOf('/');
    final ns = slashIdx != -1 ? model.name.substring(0, slashIdx) : '';

    return InkWell(
      onTap: () async {
        HapticFeedback.selectionClick();
        ref.read(selectedModelProvider.notifier).state = model.name;
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          try {
            await conn.setModelEnabled(model.name, true, provider: model.provider);
            ref.invalidate(modelsProvider);
          } catch (_) {}
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: NeumorphicDecoration.recessed(radius: 10),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: HermesTokens.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? HermesTokens.accent : HermesTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ns.isNotEmpty ? "$ns • ${model.provider}" : model.provider,
                    style: const TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: HermesTokens.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 16, color: HermesTokens.textMuted),
          ],
        ),
      ),
    );
  }

  static String _cleanFormat(String raw) {
    final slashIdx = raw.indexOf('/');
    String modelPart = slashIdx != -1 ? raw.substring(slashIdx + 1) : raw;
    modelPart = modelPart
        .replaceAll(':free', '')
        .replaceAll(':beta', '')
        .replaceAll(':exact', '');
    if (modelPart.isEmpty) return raw;
    final segments = modelPart.split(RegExp(r'[-_]'));
    return segments.map((seg) {
      if (seg.isEmpty) return '';
      final lower = seg.toLowerCase();
      if (lower == 'gpt') return 'GPT';
      if (lower == 'claude') return 'Claude';
      if (lower == 'llama') return 'Llama';
      if (lower == 'gemini') return 'Gemini';
      if (lower == 'deepseek') return 'DeepSeek';
      if (lower == 'qwen') return 'Qwen';
      if (lower == 'mistral') return 'Mistral';
      if (lower == 'instruct') return 'Instruct';
      if (lower == 'flash') return 'Flash';
      if (lower == 'pro') return 'Pro';
      if (lower == 'sonnet') return 'Sonnet';
      if (lower == 'opus') return 'Opus';
      if (lower == 'haiku') return 'Haiku';
      return seg[0].toUpperCase() + seg.substring(1);
    }).join(' ');
  }
}
