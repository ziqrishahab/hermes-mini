import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/hermes_connection.dart';
import '../../../providers/connection_provider.dart';

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

final mcpServersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getMcpServers();
});

final mcpCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getMcpCatalog();
});

final pluginsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getPlugins();
});

final pluginCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  return conn.getPluginCatalog();
});

final systemStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return null;
  return conn.getSystemStats();
});
