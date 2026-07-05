import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/config/dev_config.dart';
import 'src/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDevMode) {
    final storage = StorageService();
    final existing = await storage.loadConfig();
    if (existing == null) {
      await storage.saveConfig(DevConfig.connectionConfig);
    }
  }

  runApp(const ProviderScope(child: HermesMobileApp()));
}
