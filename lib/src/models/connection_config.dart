enum ConnectionMode { remote, sshTunnel }

class ConnectionConfig {
  final ConnectionMode mode;

  // Remote mode
  final String? apiUrl;
  final String? apiKey;

  // SSH mode
  final String? sshHost;
  final int? sshPort;
  final String? sshUsername;
  final String? privateKeyPath;
  final int? remoteHermesPort;

  const ConnectionConfig({
    required this.mode,
    this.apiUrl,
    this.apiKey,
    this.sshHost,
    this.sshPort,
    this.sshUsername,
    this.privateKeyPath,
    this.remoteHermesPort,
  });

  bool get isComplete {
    if (mode == ConnectionMode.remote) {
      return apiUrl != null && apiUrl!.isNotEmpty && apiKey != null;
    }
    return sshHost != null &&
        sshHost!.isNotEmpty &&
        sshUsername != null &&
        sshUsername!.isNotEmpty &&
        privateKeyPath != null &&
        privateKeyPath!.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'apiUrl': apiUrl,
    'apiKey': apiKey,
    'sshHost': sshHost,
    'sshPort': sshPort,
    'sshUsername': sshUsername,
    'privateKeyPath': privateKeyPath,
    'remoteHermesPort': remoteHermesPort,
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      mode: ConnectionMode.values.byName(json['mode'] as String),
      apiUrl: json['apiUrl'] as String?,
      apiKey: json['apiKey'] as String?,
      sshHost: json['sshHost'] as String?,
      sshPort: json['sshPort'] as int?,
      sshUsername: json['sshUsername'] as String?,
      privateKeyPath: json['privateKeyPath'] as String?,
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
      remoteHermesPort: remoteHermesPort ?? this.remoteHermesPort,
    );
  }
}
