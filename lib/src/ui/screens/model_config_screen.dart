import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../models/agent_profile.dart";
import "../../providers/chat_provider.dart";
import "../../providers/connection_provider.dart";
import "../../providers/profiles_provider.dart";
import "../../services/hermes_connection.dart";
import "../../theme.dart";
import "../widgets/hermes_toast.dart";
import "../widgets/neumorphic_skeleton.dart";

/// Reusable inference provider preset stored locally on device.
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
    if (lower.contains('deepseek')) return 'DeepSeek';
    if (lower.contains('localhost') || lower.contains('127.0.0.1')) {
      return 'Local LLM';
    }
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) {
        final parts = uri.host.split('.');
        if (parts.length >= 2) {
          final domainName =
              (parts.length > 2 && parts[0] != 'www' && parts[0] != 'api')
                  ? parts[0]
                  : parts[parts.length - 2];
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
  final String? initialProfile;

  const ModelConfigScreen({super.key, this.initialProfile});

  @override
  ConsumerState<ModelConfigScreen> createState() => _ModelConfigScreenState();
}

class _ModelConfigScreenState extends ConsumerState<ModelConfigScreen> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _modelsScrollCtrl = ScrollController();

  late String _targetProfile;
  String? _profileSelectedModel;
  String? _profileServerProvider;
  String _searchQuery = '';
  String _selectedFamilyFilter = 'All';
  bool _obscureKey = true;
  bool _saving = false;
  bool _loadingProfile = false;
  bool _syncAllProfiles = false;

  List<SavedProviderProfile> _savedProviders = [];

  static String _baseUrlPrefKey(String profile) => profile == 'default'
      ? 'custom_inference_base_url'
      : 'custom_inference_base_url__$profile';

  static String _apiKeyPrefKey(String profile) => profile == 'default'
      ? 'custom_inference_api_key'
      : 'custom_inference_api_key__$profile';

  static String _selectedModelPrefKey(String profile) => profile == 'default'
      ? 'active_selected_model'
      : 'active_selected_model__$profile';

  static bool _isMaskedSecret(String? val) {
    if (val == null) return true;
    final trimmed = val.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^\*+$').hasMatch(trimmed) ||
        trimmed.contains('****') ||
        trimmed.contains('••••');
  }

  @override
  void initState() {
    super.initState();
    final initProf = widget.initialProfile?.trim() ?? '';
    _targetProfile =
        initProf.isNotEmpty ? initProf : ref.read(activeProfileProvider);
    _loadConfigForProfile(_targetProfile);
  }

  Future<void> _loadConfigForProfile(String profileId) async {
    final cleanProfile = profileId.trim().isEmpty ? 'default' : profileId.trim();
    setState(() {
      _loadingProfile = true;
      _nameCtrl.clear();
      _urlCtrl.clear();
      _apiKeyCtrl.clear();
      _profileSelectedModel = null;
      _profileServerProvider = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_baseUrlPrefKey(cleanProfile)) ?? '';
      final savedKey = prefs.getString(_apiKeyPrefKey(cleanProfile)) ?? '';
      final savedModel =
          prefs.getString(_selectedModelPrefKey(cleanProfile)) ?? '';

      String resolvedUrl = savedUrl;
      String resolvedKey = !_isMaskedSecret(savedKey) ? savedKey : '';
      String resolvedModel = savedModel;
      String resolvedProvider = '';

      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        final info = await conn.getModelInfo(profile: cleanProfile);
        if (info.isNotEmpty) {
          final srvModel = info['model']?.toString() ?? '';
          final srvProvider = info['provider']?.toString() ?? '';
          final srvUrl = info['base_url']?.toString() ?? '';
          if (srvModel.isNotEmpty) resolvedModel = srvModel;
          if (srvProvider.isNotEmpty) resolvedProvider = srvProvider;
          if (resolvedUrl.isEmpty && srvUrl.isNotEmpty) {
            resolvedUrl = srvUrl;
          } else if (resolvedUrl.isEmpty &&
              srvProvider.toLowerCase() == 'openrouter') {
            resolvedUrl = 'https://openrouter.ai/api/v1';
          }
        }

        if (resolvedUrl.isEmpty) {
          final cfgUrl =
              await conn.getConfigValue('custom_provider_url', profile: cleanProfile);
          if (cfgUrl.isNotEmpty) {
            resolvedUrl = cfgUrl;
          }
        }

        if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
          final env = await conn.readEnv(profile: cleanProfile);
          if (resolvedUrl.isEmpty) {
            final envUrl = env['CUSTOM_BASE_URL'] ??
                env['DEEPSEEK_BASE_URL'] ??
                env['OPENAI_BASE_URL'] ??
                '';
            if (envUrl.isNotEmpty && !_isMaskedSecret(envUrl)) {
              resolvedUrl = envUrl;
            }
          }
          if (resolvedKey.isEmpty) {
            final envKey = env['CUSTOM_API_KEY'] ??
                env['OPENROUTER_API_KEY'] ??
                env['ANTHROPIC_API_KEY'] ??
                env['DEEPSEEK_API_KEY'] ??
                env['OPENAI_API_KEY'] ??
                '';
            if (envKey.isNotEmpty && !_isMaskedSecret(envKey)) {
              resolvedKey = envKey;
            }
          }
        }
      }

      await _loadSavedProviders(prefs, resolvedUrl.trim(), resolvedKey.trim());

      if (!mounted || _targetProfile != cleanProfile) return;

      final matchedSaved = _savedProviders
          .where((p) =>
              resolvedUrl.isNotEmpty &&
              p.baseUrl.trim().toLowerCase() == resolvedUrl.trim().toLowerCase())
          .firstOrNull;

      setState(() {
        _urlCtrl.text = resolvedUrl;
        _apiKeyCtrl.text = resolvedKey;
        if (matchedSaved != null) {
          _nameCtrl.text = matchedSaved.name;
        }
        _profileSelectedModel = resolvedModel.isNotEmpty ? resolvedModel : null;
        _profileServerProvider =
            resolvedProvider.isNotEmpty ? resolvedProvider : null;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _loadSavedProviders(
    SharedPreferences prefs,
    String currentUrl,
    String currentKey,
  ) async {
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
      } else if (cleanKey.isNotEmpty && list[existingIdx].apiKey.isEmpty) {
        list[existingIdx] = SavedProviderProfile(
          id: list[existingIdx].id,
          name: list[existingIdx].name,
          baseUrl: cleanUrl,
          apiKey: cleanKey,
          lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
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

  Future<void> _applyEndpointToTargets({
    required HermesConnection conn,
    required SharedPreferences prefs,
    required String baseUrl,
    required String apiKey,
  }) async {
    final targets = <String>{_targetProfile};
    if (_syncAllProfiles) {
      final allProfiles = ref.read(profilesListProvider).valueOrNull ?? [];
      for (final p in allProfiles) {
        if (p.id.trim().isNotEmpty) {
          targets.add(p.id.trim());
        }
      }
    }

    for (final prof in targets) {
      await prefs.setString(_baseUrlPrefKey(prof), baseUrl);
      if (apiKey.isNotEmpty) {
        await prefs.setString(_apiKeyPrefKey(prof), apiKey);
      }
      await prefs.remove(_selectedModelPrefKey(prof));
      await conn.setCustomInferenceEndpoint(
        baseUrl: baseUrl,
        apiKey: apiKey,
        profile: prof,
      );
      ref.invalidate(profileModelsProvider(prof));
    }

    ref.invalidate(profilesListProvider);
    final activeProf = ref.read(activeProfileProvider);
    if (targets.contains(activeProf)) {
      ref.invalidate(modelsProvider);
    }
  }

  Future<void> _selectProvider(SavedProviderProfile preset) async {
    if (_saving) return;
    HapticFeedback.selectionClick();

    setState(() {
      _saving = true;
      _nameCtrl.text = preset.name;
      _urlCtrl.text = preset.baseUrl;
      _apiKeyCtrl.text = preset.apiKey;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = _savedProviders.indexWhere((x) => x.id == preset.id);
      if (idx != -1) {
        _savedProviders[idx] = SavedProviderProfile(
          id: preset.id,
          name: preset.name,
          baseUrl: preset.baseUrl,
          apiKey: preset.apiKey,
          lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
        );
        await _saveProviderProfiles();
      }

      final conn = ref.read(connectionProvider).valueOrNull;
      if (conn != null) {
        await _applyEndpointToTargets(
          conn: conn,
          prefs: prefs,
          baseUrl: preset.baseUrl,
          apiKey: preset.apiKey,
        );
        final fetchedModels =
            await ref.read(profileModelsProvider(_targetProfile).future);
        final enabledModel =
            fetchedModels.where((m) => m.enabled).firstOrNull?.name;
        if (mounted && enabledModel != null && enabledModel.isNotEmpty) {
          setState(() => _profileSelectedModel = enabledModel);
        }
      }

      final fetchErr = conn?.lastModelFetchError;
      if (mounted) {
        if (fetchErr != null && fetchErr.isNotEmpty) {
          HermesToast.show(
            context,
            message: "Applied ${preset.name}, provider reported: $fetchErr",
            type: HermesToastType.error,
          );
        } else {
          final targetLabel =
              _syncAllProfiles ? "all profiles" : "profile '$_targetProfile'";
          HermesToast.show(
            context,
            message: "Applied ${preset.name} to $targetLabel",
            type: HermesToastType.info,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        HermesToast.show(
          context,
          message: "Failed to switch provider: $e",
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
        message: "Removed ${profile.name} from saved presets",
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HermesTokens.textPrimary,
          ),
        ),
        content: Text(
          "Remove this saved provider preset (${prov.baseUrl}) from your device?",
          style: TextStyle(fontSize: 13, color: HermesTokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text("Cancel", style: TextStyle(color: HermesTokens.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProvider(prov);
            },
            child: const Text(
              "Remove",
              style: TextStyle(
                  color: HermesTokens.error, fontWeight: FontWeight.w700),
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
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final key = _apiKeyCtrl.text.trim();

    if (url.isEmpty && key.isEmpty) {
      HermesToast.show(
        context,
        message: "Enter a Base URL or API key before saving",
        type: HermesToastType.error,
      );
      return;
    }

    setState(() => _saving = true);
    final conn = ref.read(connectionProvider).valueOrNull;

    try {
      if (conn != null) {
        final prefs = await SharedPreferences.getInstance();

        if (url.isNotEmpty) {
          final resolvedName = name.isNotEmpty
              ? name
              : SavedProviderProfile.guessProviderName(url);

          final existingIdx = _savedProviders.indexWhere(
              (p) => p.baseUrl.trim().toLowerCase() == url.toLowerCase());
          if (existingIdx != -1) {
            _savedProviders[existingIdx] = SavedProviderProfile(
              id: _savedProviders[existingIdx].id,
              name: name.isNotEmpty ? name : _savedProviders[existingIdx].name,
              baseUrl: url,
              apiKey: key.isNotEmpty ? key : _savedProviders[existingIdx].apiKey,
              lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
            );
          } else {
            _savedProviders.insert(
              0,
              SavedProviderProfile(
                id: 'prov_${DateTime.now().millisecondsSinceEpoch}',
                name: resolvedName,
                baseUrl: url,
                apiKey: key,
                lastUsedEpoch: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
          await _saveProviderProfiles();

          await _applyEndpointToTargets(
            conn: conn,
            prefs: prefs,
            baseUrl: url,
            apiKey: key,
          );
        } else if (key.isNotEmpty) {
          final targets = <String>{_targetProfile};
          if (_syncAllProfiles) {
            final allProfiles =
                ref.read(profilesListProvider).valueOrNull ?? [];
            for (final p in allProfiles) {
              if (p.id.trim().isNotEmpty) targets.add(p.id.trim());
            }
          }
          final modelFallback = _profileSelectedModel ?? 'gpt-4o';
          final provFallback = _profileServerProvider ?? 'openrouter';
          for (final prof in targets) {
            await prefs.setString(_apiKeyPrefKey(prof), key);
            await conn.setModelProviderKey(
              modelFallback,
              provFallback,
              key,
              profile: prof,
            );
            ref.invalidate(profileModelsProvider(prof));
          }
          ref.invalidate(profilesListProvider);
          if (targets.contains(ref.read(activeProfileProvider))) {
            ref.invalidate(modelsProvider);
          }
        }

        final fetchedModels =
            await ref.read(profileModelsProvider(_targetProfile).future);
        final enabledModel =
            fetchedModels.where((m) => m.enabled).firstOrNull?.name;
        if (mounted && enabledModel != null && enabledModel.isNotEmpty) {
          setState(() => _profileSelectedModel = enabledModel);
        }

        final fetchErr = conn.lastModelFetchError;
        if (mounted) {
          if (fetchErr != null && fetchErr.isNotEmpty) {
            HermesToast.show(
              context,
              message: "Saved, provider returned: $fetchErr",
              type: HermesToastType.error,
            );
          } else {
            final targetLabel =
                _syncAllProfiles ? "all profiles" : "profile '$_targetProfile'";
            HermesToast.show(
              context,
              message: "Provider configuration saved for $targetLabel",
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
    final profilesAsync = ref.watch(profilesListProvider);
    final profiles = profilesAsync.valueOrNull ??
        const [
          AgentProfile(id: 'default', name: 'Default Agent', isDefault: true),
        ];

    final hasTargetInList = profiles.any((p) => p.id == _targetProfile);
    final dropdownProfiles = hasTargetInList
        ? profiles
        : [
            ...profiles,
            AgentProfile(
              id: _targetProfile,
              name: _targetProfile == 'default'
                  ? 'Default Agent'
                  : _targetProfile,
              isDefault: _targetProfile == 'default',
            ),
          ];

    final modelsAsync = ref.watch(profileModelsProvider(_targetProfile));
    final models = modelsAsync.valueOrNull ?? [];
    final enabledFromCatalog = models.where((m) => m.enabled).firstOrNull;
    final effectiveModelName =
        (_profileSelectedModel != null && _profileSelectedModel!.isNotEmpty)
            ? _profileSelectedModel!
            : (enabledFromCatalog?.name ?? '');

    final currentConfig =
        models.where((x) => x.name == effectiveModelName).firstOrNull ??
            enabledFromCatalog;
    final providerLabel = currentConfig?.provider.isNotEmpty == true
        ? currentConfig!.provider
        : (_profileServerProvider ?? 'Not configured');

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
      if (l.contains('gemini') ||
          l.contains('google') ||
          p.contains('google')) {
        detectedFamilies.add('Gemini');
      } else if (l.contains('gpt') ||
          l.contains('openai') ||
          p.contains('openai')) {
        detectedFamilies.add('GPT');
      } else if (l.contains('qwen') || l.contains('alibaba')) {
        detectedFamilies.add('Qwen');
      } else if (l.contains('deepseek')) {
        detectedFamilies.add('DeepSeek');
      } else if (l.contains('claude') ||
          l.contains('anthropic') ||
          p.contains('anthropic')) {
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
        if (!l.contains('gemini') &&
            !l.contains('google') &&
            !p.contains('google')) {
          return false;
        }
      } else if (_selectedFamilyFilter == 'GPT') {
        if (!l.contains('gpt') &&
            !l.contains('openai') &&
            !p.contains('openai')) {
          return false;
        }
      } else if (_selectedFamilyFilter == 'Qwen') {
        if (!l.contains('qwen') && !l.contains('alibaba')) return false;
      } else if (_selectedFamilyFilter == 'DeepSeek') {
        if (!l.contains('deepseek')) return false;
      } else if (_selectedFamilyFilter == 'Claude') {
        if (!l.contains('claude') &&
            !l.contains('anthropic') &&
            !p.contains('anthropic')) {
          return false;
        }
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

    final fetchError =
        ref.watch(connectionProvider).valueOrNull?.lastModelFetchError;
    final matchedProfile =
        dropdownProfiles.where((p) => p.id == _targetProfile).firstOrNull;
    final profileTitle =
        (matchedProfile != null && matchedProfile.name.trim().isNotEmpty)
            ? matchedProfile.name.trim()
            : (_targetProfile == 'default' ? 'Default Agent' : _targetProfile);

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
              decoration:
                  NeumorphicDecoration.raised(radius: 12, distance: 2.5, blur: 5),
              child: IconButton(
                tooltip: "Back",
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: HermesTokens.textPrimary, size: 16),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          "Model ($profileTitle)",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
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
              // 1. Assigned Model Summary (No decorative badges or status dots)
              _sectionLabel("ASSIGNED MODEL"),
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
                      child: Icon(
                        Icons.psychology_outlined,
                        color: HermesTokens.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loadingProfile
                                ? "Loading profile configuration..."
                                : (effectiveModelName.isNotEmpty
                                    ? effectiveModelName
                                    : "No model assigned"),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadingProfile
                                ? "Reading profile settings"
                                : "Provider: $providerLabel",
                            style: TextStyle(
                              fontSize: 12,
                              color: HermesTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // 3. Provider Vault & Endpoint Credentials
              _sectionLabel("INFERENCE PROVIDER"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: NeumorphicDecoration.raised(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "SAVED PROVIDERS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: HermesTokens.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_savedProviders.isNotEmpty)
                          Text(
                            "${_savedProviders.length} saved on device",
                            style: TextStyle(
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
                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _nameCtrl.clear();
                                  _urlCtrl.clear();
                                  _apiKeyCtrl.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration:
                                    NeumorphicDecoration.recessed(radius: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 16,
                                        color: HermesTokens.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      "New",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: HermesTokens.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final prov = _savedProviders[idx];
                          final isCurrent = _urlCtrl.text.trim().isNotEmpty &&
                              _urlCtrl.text.trim().toLowerCase() ==
                                  prov.baseUrl.trim().toLowerCase();

                          return InkWell(
                            onTap: () => _selectProvider(prov),
                            onLongPress: () => _confirmDeleteProvider(prov),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: isCurrent
                                  ? NeumorphicDecoration.recessed(radius: 12)
                                  : NeumorphicDecoration.raised(
                                      radius: 12,
                                      distance: 2,
                                      blur: 4,
                                    ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    prov.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: isCurrent
                                          ? HermesTokens.accent
                                          : HermesTokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _confirmDeleteProvider(prov),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                      color: HermesTokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      "Provider Label (Optional)",
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
                        style: TextStyle(
                            color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: "Optional identifier",
                          hintStyle: TextStyle(
                              color: HermesTokens.textMuted, fontSize: 13),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
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
                        keyboardType: TextInputType.url,
                        style: TextStyle(
                            color: HermesTokens.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: "https://host/v1",
                          hintStyle: TextStyle(
                              color: HermesTokens.textMuted, fontSize: 13),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
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
                              keyboardType: TextInputType.visiblePassword,
                              style: TextStyle(
                                  color: HermesTokens.textPrimary,
                                  fontSize: 13),
                              decoration: InputDecoration(
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: "API key",
                                hintStyle: TextStyle(
                                    color: HermesTokens.textMuted,
                                    fontSize: 13),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                _obscureKey ? "Show API key" : "Hide API key",
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

                    if (dropdownProfiles.length > 1) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: NeumorphicDecoration.recessed(radius: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Apply to all agent profiles",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: HermesTokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Sync this Base URL and API key across every profile",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: HermesTokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _syncAllProfiles,
                              activeTrackColor: HermesTokens.accent,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _syncAllProfiles = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
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
                                : Text(
                                    _syncAllProfiles
                                        ? "Save for All Profiles"
                                        : "Save Provider Configuration",
                                    style: const TextStyle(
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

              // 4. Available Models Catalog (Pure Neumorphic, no badges or glows)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel("AVAILABLE MODELS"),
                  if (models.isNotEmpty)
                    Text(
                      filteredModels.length == models.length
                          ? "${models.length} available"
                          : "${filteredModels.length} of ${models.length}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: HermesTokens.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (fetchError != null && fetchError.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: HermesTokens.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fetchError,
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

              if ((modelsAsync.isLoading || _loadingProfile) && models.isEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: const ModelListSkeleton(count: 4),
                )
              else if (models.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: NeumorphicDecoration.raised(radius: 18),
                  child: Column(
                    children: [
                      Icon(Icons.dns_outlined,
                          color: HermesTokens.textMuted, size: 32),
                      const SizedBox(height: 10),
                      Text(
                        "No models configured for this profile",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HermesTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _savedProviders.isNotEmpty
                            ? "Select one of your saved providers above or enter a Base URL and API key to load models."
                            : "Enter a Base URL and API key above, then save to fetch available models.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: HermesTokens.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  decoration: NeumorphicDecoration.recessed(radius: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded,
                          size: 18, color: HermesTokens.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: TextStyle(
                              color: HermesTokens.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: "Search model or provider...",
                            hintStyle: TextStyle(
                                color: HermesTokens.textMuted, fontSize: 13),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: Icon(Icons.clear_rounded,
                              size: 18, color: HermesTokens.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Neumorphic Family Filter Row (no glow shadows or pill badges)
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: availableFilters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                          decoration: isChipSelected
                              ? NeumorphicDecoration.recessed(radius: 10)
                              : NeumorphicDecoration.raised(
                                  radius: 10,
                                  distance: 2,
                                  blur: 4,
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
                                    ? HermesTokens.accent
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
                                  Icon(Icons.search_off_rounded,
                                      size: 32, color: HermesTokens.textMuted),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedFamilyFilter != 'All'
                                        ? "No models match filter \"$_selectedFamilyFilter\""
                                        : "No models match \"$_searchQuery\"",
                                    style: TextStyle(
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
                                    child: Text(
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
                              padding: const EdgeInsets.all(8),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredModels.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, i) => _modelSelectTile(
                                  filteredModels[i], effectiveModelName),
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
          style: TextStyle(
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
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        HapticFeedback.selectionClick();
        setState(() {
          _profileSelectedModel = model.name;
          if (model.provider.isNotEmpty) {
            _profileServerProvider = model.provider;
          }
        });
        if (_targetProfile == ref.read(activeProfileProvider)) {
          ref.read(selectedModelProvider.notifier).state = model.name;
        }
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          try {
            await conn.setModelEnabled(
              model.name,
              true,
              provider: model.provider,
              profile: _targetProfile,
            );
            ref.invalidate(profileModelsProvider(_targetProfile));
            ref.invalidate(profilesListProvider);
            if (_targetProfile == ref.read(activeProfileProvider)) {
              ref.invalidate(modelsProvider);
            }
          } catch (_) {}
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: isSelected
            ? NeumorphicDecoration.recessed(radius: 12)
            : const BoxDecoration(),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: NeumorphicDecoration.recessed(radius: 10),
              child: Icon(
                Icons.memory_rounded,
                size: 16,
                color:
                    isSelected ? HermesTokens.accent : HermesTokens.textMuted,
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? HermesTokens.accent
                          : HermesTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ns.isNotEmpty ? "$ns / ${model.provider}" : model.provider,
                    style:
                        TextStyle(fontSize: 11, color: HermesTokens.textMuted),
                  ),
                ],
              ),
            ),
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
