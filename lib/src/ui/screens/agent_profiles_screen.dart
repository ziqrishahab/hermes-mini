import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/agent_profile.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/profiles_provider.dart';
import '../../theme.dart';
import '../widgets/hermes_toast.dart';
import '../widgets/tactile_feedback.dart';

class AgentProfilesScreen extends ConsumerStatefulWidget {
  const AgentProfilesScreen({super.key});

  @override
  ConsumerState<AgentProfilesScreen> createState() =>
      _AgentProfilesScreenState();
}

class _AgentProfilesScreenState extends ConsumerState<AgentProfilesScreen> {
  bool _busy = false;

  void _showCreateDialog(List<AgentProfile> existingProfiles) {
    final nameCtrl = TextEditingController();
    String? selectedClone = 'default';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HermesTokens.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
            side: BorderSide(color: HermesTokens.borderBright),
          ),
          title: Text(
            "Create Agent Profile",
            style: TextStyle(
              color: HermesTokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "PROFILE IDENTIFIER",
                  style: TextStyle(
                    color: HermesTokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(
                      color: HermesTokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. coding-assistant",
                      hintStyle: TextStyle(
                        color: HermesTokens.textMuted,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (_) {
                    final raw = nameCtrl.text.trim();
                    if (raw.isEmpty) {
                      return Text(
                        "Allowed: lowercase letters, numbers, hyphens (-), and underscores (_).",
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.textMuted,
                        ),
                      );
                    }
                    final slug = AgentProfile.canonicalizeId(raw);
                    if (slug.isEmpty) {
                      return Text(
                        "Identifier must contain alphanumeric characters.",
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.error,
                        ),
                      );
                    }
                    if (slug == 'default') {
                      return Text(
                        "Identifier 'default' is reserved.",
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.error,
                        ),
                      );
                    }
                    if (slug != raw) {
                      return Text(
                        "Identifier: $slug",
                        style: TextStyle(
                          fontSize: 11,
                          color: HermesTokens.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return Text(
                      "Valid identifier: $slug",
                      style: TextStyle(
                        fontSize: 11,
                        color: HermesTokens.textMuted,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  "CLONE FROM",
                  style: TextStyle(
                    color: HermesTokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: NeumorphicDecoration.recessed(radius: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedClone,
                      isExpanded: true,
                      dropdownColor: HermesTokens.bgElevated,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            "None (Blank profile)",
                            style: TextStyle(
                              fontSize: 12,
                              color: HermesTokens.textPrimary,
                            ),
                          ),
                        ),
                        ...existingProfiles.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(
                              "${p.name} (${p.id})",
                              style: TextStyle(
                                color: HermesTokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedClone = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedClone != null
                      ? "Copies LLM credentials and configuration from the selected profile."
                      : "Starts empty. Configure an LLM provider in Model settings before chatting.",
                  style: TextStyle(
                    fontSize: 11,
                    color: HermesTokens.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: HermesTokens.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TactileContainer(
              onTap: () async {
                final raw = nameCtrl.text.trim();
                if (raw.isEmpty) return;
                final slug = AgentProfile.canonicalizeId(raw);
                if (slug.isEmpty) {
                  HermesToast.show(
                    context,
                    message: "Profile identifier must contain alphanumeric characters",
                    type: HermesToastType.error,
                  );
                  return;
                }
                if (slug == 'default') {
                  HermesToast.show(
                    context,
                    message: "Profile 'default' is reserved",
                    type: HermesToastType.error,
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _handleCreateProfile(
                  slug,
                  selectedClone,
                  description: raw != slug ? raw : null,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: NeumorphicDecoration.raised(
                  radius: 10,
                  color: HermesTokens.accent,
                  distance: 2,
                  blur: 4,
                ),
                child: const Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateProfile(
    String id,
    String? cloneFrom, {
    String? description,
  }) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) {
      HermesToast.show(
        context,
        message: "Not connected to Hermes instance",
        type: HermesToastType.error,
      );
      return;
    }

    setState(() => _busy = true);
    String? serverError;
    final success = await conn.createProfile(
      id,
      cloneFrom: cloneFrom,
      description: description,
      onError: (err) => serverError = err,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (success) {
      HermesToast.show(
        context,
        message: "Profile '$id' created",
        type: HermesToastType.success,
      );
      ref.invalidate(profilesListProvider);
      ref.invalidate(profileModelsProvider(id));
    } else {
      HermesToast.show(
        context,
        message: serverError ?? "Failed to create profile",
        type: HermesToastType.error,
      );
    }
  }

  void _confirmDeleteProfile(AgentProfile profile) {
    if (profile.isDefault || profile.id == 'default') return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HermesTokens.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesTokens.radiusMd),
          side: BorderSide(color: HermesTokens.borderBright),
        ),
        title: Text(
          "Delete Profile '${profile.name}'?",
          style: TextStyle(
            color: HermesTokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "This removes the profile directory, isolated memory, and credentials from the server.",
          style: TextStyle(
            color: HermesTokens.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: HermesTokens.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleDeleteProfile(profile);
            },
            child: const Text(
              "Delete",
              style: TextStyle(
                color: HermesTokens.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteProfile(AgentProfile profile) async {
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn == null) return;

    setState(() => _busy = true);
    final ok = await conn.deleteProfile(profile.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      if (ref.read(activeProfileProvider) == profile.id) {
        await ref.read(activeProfileProvider.notifier).setProfile('default');
        ref.invalidate(modelsProvider);
      }
      ref.invalidate(profilesListProvider);
      ref.invalidate(sessionsProvider);
      if (mounted) {
        HermesToast.show(
          context,
          message: "Profile '${profile.name}' deleted",
          type: HermesToastType.info,
        );
      }
    } else {
      HermesToast.show(
        context,
        message: "Failed to delete profile '${profile.name}'",
        type: HermesToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profilesListProvider);

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
              decoration: NeumorphicDecoration.raised(
                radius: 12,
                distance: 2.5,
                blur: 5,
              ),
              child: IconButton(
                tooltip: "Back",
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: HermesTokens.textPrimary,
                  size: 16,
                ),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        title: Text(
          "Agent Profiles",
          style: TextStyle(
            fontSize: 17,
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
                decoration: NeumorphicDecoration.raised(
                  radius: 12,
                  distance: 2.5,
                  blur: 5,
                ),
                child: IconButton(
                  tooltip: "New Profile",
                  icon: Icon(
                    Icons.add_rounded,
                    color: HermesTokens.accent,
                    size: 20,
                  ),
                  onPressed: () {
                    final list = profilesAsync.valueOrNull ?? [];
                    _showCreateDialog(list);
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 36,
                          color: HermesTokens.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Failed to load profiles",
                          style: TextStyle(
                            color: HermesTokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(profilesListProvider),
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (profiles) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(profilesListProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: profiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildProfileItem(profiles[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(AgentProfile profile) {
    final cleanModel = (profile.model != null && profile.model!.isNotEmpty)
        ? profile.model!.split('/').last
        : 'Unassigned model';
    final canDelete = !profile.isDefault && profile.id != 'default';

    return Container(
      decoration: NeumorphicDecoration.raised(
        radius: 16,
        distance: 2.5,
        blur: 5.0,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: NeumorphicDecoration.recessed(radius: 10),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: HermesTokens.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        color: HermesTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$cleanModel, ${profile.skillCount} skills",
                      style: TextStyle(
                        fontSize: 11,
                        color: HermesTokens.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: NeumorphicDecoration.raised(
                    radius: 10,
                    distance: 2,
                    blur: 4,
                  ),
                  child: IconButton(
                    tooltip: "Delete profile",
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: HermesTokens.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _confirmDeleteProfile(profile),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.subject_rounded,
                  label: "Soul",
                  onTap: () => context.push('/soul-editor', extra: profile.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.psychology_outlined,
                  label: "Memory",
                  onTap: () => context.push('/memory-editor', extra: profile.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.tune_rounded,
                  label: "Model",
                  onTap: () => context.push('/model-config', extra: profile.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TactileContainer(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: NeumorphicDecoration.raised(
          radius: 10,
          distance: 2,
          blur: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: HermesTokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: HermesTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
