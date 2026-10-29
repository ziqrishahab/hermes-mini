import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/registry_item.dart';
import 'hermes_connection.dart';

class RegistryService {
  static const String _registryUrl =
      'https://raw.githubusercontent.com/fathah/hermes-registry/main/index.json';
  static const String _cacheKey = 'hermes_registry_catalog_cache';

  static List<RegistryItem>? _memoryCache;

  static final List<RegistryItem> _curatedFallback = [
    const RegistryItem(
      id: 'browser',
      name: 'Browser Automation',
      description: 'Web automation and scraping using headless browser engines.',
      type: 'mcp',
      author: 'hermes',
      category: 'automation',
      tags: ['web', 'scraping', 'mcp'],
    ),
    const RegistryItem(
      id: 'github',
      name: 'GitHub Integration',
      description: 'Interact with GitHub repositories, PRs, issues, and code search.',
      type: 'mcp',
      author: 'github',
      category: 'development',
      tags: ['git', 'code', 'mcp'],
    ),
    const RegistryItem(
      id: 'postgres',
      name: 'PostgreSQL Explorer',
      description: 'Query, inspect tables, and manage relational database schemas.',
      type: 'mcp',
      author: 'community',
      category: 'database',
      tags: ['sql', 'database', 'mcp'],
    ),
    const RegistryItem(
      id: 'code-review',
      name: 'Code Reviewer',
      description: 'Systematic diff inspection and clean code standards auditing.',
      type: 'skill',
      author: 'hermes',
      category: 'coding',
      tags: ['code', 'review', 'skill'],
    ),
    const RegistryItem(
      id: 'web-search',
      name: 'Live Web Search',
      description: 'Real-time search queries and web document summarization.',
      type: 'skill',
      author: 'hermes',
      category: 'search',
      tags: ['search', 'web', 'skill'],
    ),
    const RegistryItem(
      id: 'notion',
      name: 'Notion Workspace',
      description: 'Read and update pages, databases, and task lists in Notion.',
      type: 'mcp',
      author: 'community',
      category: 'productivity',
      tags: ['notes', 'notion', 'mcp'],
    ),
    const RegistryItem(
      id: 'filesystem',
      name: 'Local Filesystem MCP',
      description: 'Safe sandboxed directory traversal and local file inspection.',
      type: 'mcp',
      author: 'anthropic',
      category: 'system',
      tags: ['files', 'disk', 'mcp'],
    ),
  ];

  static Future<List<RegistryItem>> fetchCatalog({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache!;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final res = await dio.get(_registryUrl);
      if (res.statusCode == 200) {
        dynamic data = res.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        List<dynamic> itemsList = [];
        if (data is List<dynamic>) {
          itemsList = data;
        } else if (data is Map<String, dynamic>) {
          // Could be keyed by kind (skills, mcps, etc.)
          if (data['items'] is List<dynamic>) {
            itemsList = data['items'] as List<dynamic>;
          } else {
            for (final k in ['skills', 'mcps', 'agents', 'workflows']) {
              if (data[k] is List<dynamic>) {
                itemsList.addAll(data[k] as List<dynamic>);
              }
            }
          }
        }

        if (itemsList.isNotEmpty) {
          final parsed = itemsList
              .whereType<Map<String, dynamic>>()
              .map((j) => RegistryItem.fromJson(j))
              .toList();

          _memoryCache = parsed;

          // Save cache in background
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(_cacheKey, jsonEncode(itemsList));
          }).catchError((_) {});

          return parsed;
        }
      }
    } catch (_) {}

    // Check disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List<dynamic>) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((j) => RegistryItem.fromJson(j))
              .toList();
          if (list.isNotEmpty) {
            _memoryCache = list;
            return list;
          }
        }
      }
    } catch (_) {}

    _memoryCache = _curatedFallback;
    return _curatedFallback;
  }

  static Future<bool> installItem(HermesConnection conn, RegistryItem item) async {
    if (item.type == 'skill') {
      return await conn.installSkill(item.source ?? item.id);
    } else if (item.type == 'mcp') {
      return await conn.installMcpCatalogEntry(item.id, {});
    }
    return false;
  }
}
