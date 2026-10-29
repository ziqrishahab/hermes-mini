import "dart:async";
import "dart:math";
import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/connection_config.dart";
import "../services/hermes_connection.dart";
import "../services/storage_service.dart";

final connectionConfigProvider = StateProvider<ConnectionConfig?>(
  (ref) => null,
);

final isOfflineModeProvider = StateProvider<bool>((ref) => false);


final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, AsyncValue<HermesConnection?>>((
      ref,
    ) {
      return ConnectionNotifier(ref);
    });

class ConnectionNotifier extends StateNotifier<AsyncValue<HermesConnection?>>
    with WidgetsBindingObserver {
  final Ref ref;
  HermesConnection? _current;
  final StorageService _storage = StorageService();

  ConnectionNotifier(this.ref) : super(const AsyncValue.data(null)) {
    WidgetsBinding.instance.addObserver(this);
    _init();
    _setupConnectivityListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectionOnResume();
    }
  }

  Future<void> _checkConnectionOnResume() async {
    final config = ref.read(connectionConfigProvider);
    if (config == null || !config.isComplete) return;

    // Verify existing connection health after waking up from background sleep
    if (_current != null) {
      try {
        final healthy = await _current!.testConnection().timeout(
          const Duration(seconds: 4),
          onTimeout: () => false,
        );
        if (healthy) return;
      } catch (_) {}
    }

    // If socket is dead or state disconnected, immediately attempt silent reconnect
    await _attemptSilentReconnect(config);
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

  Future<bool> testAndConnect(ConnectionConfig config, {bool silent = false}) async {
    if (!silent) {
      state = const AsyncValue.loading();
    }
    try {
      final conn = HermesConnectionFactory.create(config);
      final ok = await conn.testConnection().timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
      if (!ok) {
        if (!silent) {
          state = const AsyncValue.data(null);
        }
        return false;
      }
      _current?.dispose();
      _current = conn;
      ref.read(connectionConfigProvider.notifier).state = config;
      await _storage.saveConfig(config);
      state = AsyncValue.data(conn);
      return true;
    } catch (e, st) {
      if (!silent) {
        state = AsyncValue.error(e, st);
      }
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

  // Connectivity listener & auto-reconnect logic (silent like WhatsApp)
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isReconnecting = false;

  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        final config = ref.read(connectionConfigProvider);
        if (config != null && config.isComplete && (_current == null || state.hasError)) {
          await _attemptSilentReconnect(config);
        }
      }
    });
  }

  Future<void> _attemptSilentReconnect(ConnectionConfig config) async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    try {
      const maxAttempts = 5;
      int attempt = 0;
      while (attempt < maxAttempts && (_current == null || state.hasError)) {
        attempt++;
        final success = await testAndConnect(config, silent: true);
        if (success) return;
        final delaySeconds = min(30, pow(2, attempt).toInt());
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    } finally {
      _isReconnecting = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}


/// Gateway messaging platforms provider
final gatewaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final conn = ref.watch(connectionProvider).valueOrNull;
  if (conn == null) return [];
  try {
    return await conn.getMessagingPlatforms();
  } catch (_) {
    return [];
  }
});

