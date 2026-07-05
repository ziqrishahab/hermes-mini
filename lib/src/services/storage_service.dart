import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_config.dart';

class StorageService {
  static const _configKey = 'connection_config';
  static const _secureApiKey = 'hermes_api_key';
  static const _securePrivateKey = 'hermes_private_key_content';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveConfig(ConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));

    if (config.apiKey?.isNotEmpty ?? false) {
      await _secure.write(key: _secureApiKey, value: config.apiKey);
    }
  }

  Future<ConnectionConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ConnectionConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await _secure.delete(key: _secureApiKey);
    await _secure.delete(key: _securePrivateKey);
  }
}
