import "dart:async";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../config/dev_config.dart";
import "../models/connection_config.dart";
import "../services/hermes_connection.dart";
import "../services/storage_service.dart";

final connectionConfigProvider = StateProvider<ConnectionConfig?>(
  (ref) => null,
);

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, AsyncValue<HermesConnection?>>((
      ref,
    ) {
      return ConnectionNotifier(ref);
    });

class ConnectionNotifier extends StateNotifier<AsyncValue<HermesConnection?>> {
  final Ref ref;
  HermesConnection? _current;
  final StorageService _storage = StorageService();

  ConnectionNotifier(this.ref) : super(const AsyncValue.data(null)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final saved = await _storage.loadConfig();
      if (saved != null) {
        ref.read(connectionConfigProvider.notifier).state = saved;
        if (saved.isComplete) {
          await testAndConnect(saved);
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> testAndConnect(ConnectionConfig config) async {
    state = const AsyncValue.loading();
    try {
      final conn = HermesConnectionFactory.create(config);
      final ok = await conn.testConnection().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );
      if (!ok) {
        state = const AsyncValue.data(null);
        return false;
      }
      _current?.dispose();
      _current = conn;
      ref.read(connectionConfigProvider.notifier).state = config;
      await _storage.saveConfig(config);
      state = AsyncValue.data(conn);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> disconnect() async {
    _current?.dispose();
    _current = null;
    ref.read(connectionConfigProvider.notifier).state = null;
    await _storage.clearConfig();
    state = const AsyncValue.data(null);
  }
}
