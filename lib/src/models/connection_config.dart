enum ConnectionMode { remote, sshTunnel }

class ConnectionConfig {
  final ConnectionMode mode;

  // Remote mode
  final String? apiUrl;
  final String? apiKey;

  // SSH mode (legacy / deprecated)
  final String? sshHost;
  final int? sshPort;
  final String? sshUsername;
  final String? privateKeyPath;
  final String? sshPassword;
  final int? remoteHermesPort;

  const ConnectionConfig({
    this.mode = ConnectionMode.remote,
    this.apiUrl,
    this.apiKey,
    this.sshHost,
    this.sshPort,
    this.sshUsername,
    this.privateKeyPath,
    this.sshPassword,
    this.remoteHermesPort,
  });

  bool get isComplete {
    if (mode == ConnectionMode.remote) {
      return apiUrl != null && apiUrl!.isNotEmpty && apiKey != null && apiKey!.isNotEmpty;
    }
    return sshHost != null &&
        sshHost!.isNotEmpty &&
        sshUsername != null &&
        sshUsername!.isNotEmpty &&
        (privateKeyPath != null && privateKeyPath!.isNotEmpty ||
         sshPassword != null && sshPassword!.isNotEmpty);
  }

  bool get usePasswordAuth => sshPassword != null && sshPassword!.isNotEmpty;

  Map<String, dynamic> toJson({bool includeSecrets = true}) => {
    'mode': mode.name,
    'apiUrl': apiUrl,
    'apiKey': includeSecrets ? apiKey : null,
    'sshHost': sshHost,
    'sshPort': sshPort,
    'sshUsername': sshUsername,
    'privateKeyPath': privateKeyPath,
    'sshPassword': includeSecrets ? sshPassword : null,
    'remoteHermesPort': remoteHermesPort,
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      mode: ConnectionMode.values.byName(json['mode'] as String? ?? 'remote'),
      apiUrl: json['apiUrl'] as String?,
      apiKey: json['apiKey'] as String?,
      sshHost: json['sshHost'] as String?,
      sshPort: json['sshPort'] as int?,
      sshUsername: json['sshUsername'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
      sshPassword: json['sshPassword'] as String?,
      remoteHermesPort: json['remoteHermesPort'] as int?,
    );
  }

  ConnectionConfig copyWith({
    ConnectionMode? mode,
    String? apiUrl,
    String? apiKey,
    String? sshHost,
    int? sshPort,
    String? sshUsername,
    String? privateKeyPath,
    String? sshPassword,
    int? remoteHermesPort,
  }) {
    return ConnectionConfig(
      mode: mode ?? this.mode,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      sshHost: sshHost ?? this.sshHost,
      sshPort: sshPort ?? this.sshPort,
      sshUsername: sshUsername ?? this.sshUsername,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      sshPassword: sshPassword ?? this.sshPassword,
      remoteHermesPort: remoteHermesPort ?? this.remoteHermesPort,
    );
  }
}
