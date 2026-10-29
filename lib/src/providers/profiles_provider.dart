import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_profile.dart';
import '../services/hermes_connection.dart';
import 'connection_provider.dart';

class ActiveProfileNotifier extends StateNotifier<String> {
  static const String _prefKey = 'active_agent_profile';
  final Ref ref;

  ActiveProfileNotifier(this.ref) : super('default') {
    _loadSaved();
    ref.listen<AsyncValue<HermesConnection?>>(connectionProvider, (prev, next) {
      final conn = next.valueOrNull;
      if (conn != null) {
        conn.activeProfile = state;
        unawaited(conn.switchServerProfile(state));
      }
    });
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        state = saved;
        final conn = ref.read(connectionProvider).valueOrNull;
        if (conn != null) {
          conn.activeProfile = saved;
          unawaited(conn.switchServerProfile(saved));
        }
      }
    } catch (_) {}
  }

  Future<void> setProfile(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    state = clean;
    final conn = ref.read(connectionProvider).valueOrNull;
    if (conn != null) {
      conn.activeProfile = clean;
      unawaited(conn.switchServerProfile(clean));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, clean);
    } catch (_) {}
  }
}

final activeProfileProvider =
    StateNotifierProvider<ActiveProfileNotifier, String>((ref) {
  return ActiveProfileNotifier(ref);
});

final profilesListProvider = FutureProvider<List<AgentProfile>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) {
    return const [
      AgentProfile(
        id: 'default',
        name: 'Default Agent',
        isDefault: true,
      ),
    ];
  }
  return await conn.listProfiles();
});
