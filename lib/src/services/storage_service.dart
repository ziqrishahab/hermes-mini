import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_config.dart';

class StorageService {
  static const _configKey = 'connection_config';
  static const _secureApiKey = 'hermes_api_key';
  static const _onboardingKey = 'has_completed_onboarding';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  Future<void> saveConfig(ConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    // Do not save sensitive credentials in plaintext SharedPreferences
    await prefs.setString(_configKey, jsonEncode(config.toJson(includeSecrets: false)));

    if (config.apiKey?.isNotEmpty ?? false) {
      await _secure.write(key: _secureApiKey, value: config.apiKey);
    } else {
      await _secure.delete(key: _secureApiKey);
    }
  }

  Future<ConnectionConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      var config = ConnectionConfig.fromJson(json);

      // Read secret apiKey securely from FlutterSecureStorage
      final secureKey = await _secure.read(key: _secureApiKey);
      if (secureKey != null && secureKey.isNotEmpty) {
        config = config.copyWith(apiKey: secureKey);
      } else if (config.apiKey != null && config.apiKey!.isNotEmpty) {
        // Migration: migrate old plaintext key to secure storage and purge plaintext
        await _secure.write(key: _secureApiKey, value: config.apiKey);
        await prefs.setString(_configKey, jsonEncode(config.toJson(includeSecrets: false)));
      }

      return config;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await _secure.delete(key: _secureApiKey);
  }
}
