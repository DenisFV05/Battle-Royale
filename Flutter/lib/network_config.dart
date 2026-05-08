enum ServerOption { local, proxmox, custom }

class NetworkConfig {
  static const String proxmoxServer = 'ieticloudpro.ieti.cat';
  static const int proxmoxPort = 3000;

  final ServerOption serverOption;
  final String playerName;
  final String customHost;
  final int customPort;

  const NetworkConfig({
    required this.serverOption,
    required this.playerName,
    this.customHost = '127.0.0.1',
    this.customPort = 3000,
  });

  static const NetworkConfig defaults = NetworkConfig(
    serverOption: ServerOption.local,
    playerName: 'Player',
  );

  String get serverHost {
    switch (serverOption) {
      case ServerOption.local:
        return '127.0.0.1';
      case ServerOption.proxmox:
        return proxmoxServer;
      case ServerOption.custom:
        return customHost.isEmpty ? '127.0.0.1' : customHost;
    }
  }

  int get serverPort {
    switch (serverOption) {
      case ServerOption.local:
        return 3000;
      case ServerOption.proxmox:
        return proxmoxPort;
      case ServerOption.custom:
        return customPort;
    }
  }

  bool get useSecureWebSocket {
    switch (serverOption) {
      case ServerOption.local:
        return false;
      case ServerOption.proxmox:
        return false; // Change to true if Proxmox has SSL
      case ServerOption.custom:
        return false;
    }
  }

  String get serverLabel {
    switch (serverOption) {
      case ServerOption.local:
        return 'Local (127.0.0.1:3000)';
      case ServerOption.proxmox:
        return 'Proxmox ($proxmoxServer:$proxmoxPort)';
      case ServerOption.custom:
        return 'Custom ($serverHost:$serverPort)';
    }
  }

  String get wsUrl {
    final scheme = useSecureWebSocket ? 'wss' : 'ws';
    return '$scheme://$serverHost:$serverPort';
  }

  NetworkConfig copyWith({
    ServerOption? serverOption,
    String? playerName,
    String? customHost,
    int? customPort,
  }) {
    return NetworkConfig(
      serverOption: serverOption ?? this.serverOption,
      playerName: playerName ?? this.playerName,
      customHost: customHost ?? this.customHost,
      customPort: customPort ?? this.customPort,
    );
  }
}
