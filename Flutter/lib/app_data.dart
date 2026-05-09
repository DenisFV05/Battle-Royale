import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'network_config.dart';
import 'utils_websockets.dart';

enum MatchPhase { connecting, waiting, playing, finished }

// ─── BattleRoyale: Tank player ────────────────────────────────────────────────

class MultiplayerPlayer {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final int health;
  final int maxHealth;
  final bool alive;
  final String direction;
  final String facing;
  final String color;
  final int kills;
  final int score;
  final int joinOrder;
  final String pokemonId;
  final String element;

  int get gemsCollected => 0;
  bool get moving => direction != 'none';

  const MultiplayerPlayer({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.health,
    required this.maxHealth,
    required this.alive,
    required this.direction,
    required this.facing,
    required this.color,
    required this.kills,
    required this.score,
    required this.joinOrder,
    required this.pokemonId,
    required this.element,
  });

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 32).toDouble(),
      height: (json['height'] as num? ?? 32).toDouble(),
      health: (json['health'] as num? ?? 100).toInt(),
      maxHealth: (json['maxHealth'] as num? ?? 100).toInt(),
      alive: json['alive'] as bool? ?? true,
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      color: (json['color'] as String? ?? '#F4D03F').trim(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      score: (json['score'] as num? ?? 0).toInt(),
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
      pokemonId: (json['pokemonId'] as String? ?? 'pikachu').trim(),
      element: (json['element'] as String? ?? 'normal').trim(),
    );
  }
}

// ─── BattleRoyale: Bullet ─────────────────────────────────────────────────────

class BattleRoyaleBullet {
  final int id;
  final double x;
  final double y;
  final String ownerId;
  final double size;
  final String element;

  const BattleRoyaleBullet({
    required this.id,
    required this.x,
    required this.y,
    required this.ownerId,
    required this.size,
    required this.element,
  });

  factory BattleRoyaleBullet.fromJson(Map<String, dynamic> json) {
    return BattleRoyaleBullet(
      id: (json['id'] as num? ?? 0).toInt(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      ownerId: (json['ownerId'] as String? ?? '').trim(),
      size: (json['size'] as num? ?? 8).toDouble(),
      element: (json['element'] as String? ?? 'normal').trim(),
    );
  }
}

// ─── Pokémon catalogue entry (from server snapshot) ─────────────────────────

class PokemonInfo {
  final String id;
  final String name;
  final String color;
  final String element;

  const PokemonInfo({
    required this.id,
    required this.name,
    required this.color,
    required this.element,
  });

  factory PokemonInfo.fromJson(Map<String, dynamic> json) {
    return PokemonInfo(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      color: (json['color'] as String? ?? '#FFFFFF').trim(),
      element: (json['element'] as String? ?? 'normal').trim(),
    );
  }
}

// ─── BattleRoyale: Health Item ────────────────────────────────────────────────

class BattleRoyaleHealthItem {
  final int id;
  final double x;
  final double y;
  final double width;
  final double height;

  const BattleRoyaleHealthItem({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BattleRoyaleHealthItem.fromJson(Map<String, dynamic> json) {
    return BattleRoyaleHealthItem(
      id: (json['id'] as num? ?? 0).toInt(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 20).toDouble(),
      height: (json['height'] as num? ?? 20).toDouble(),
    );
  }
}

// ─── BattleRoyale: Ranking entry ─────────────────────────────────────────────

class RankingEntry {
  final int rank;
  final String id;
  final String name;
  final int kills;
  final int score;
  final bool alive;
  final String color;
  final String pokemonId;

  const RankingEntry({
    required this.rank,
    required this.id,
    required this.name,
    required this.kills,
    required this.score,
    required this.alive,
    required this.color,
    required this.pokemonId,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      rank: (json['rank'] as num? ?? 0).toInt(),
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      score: (json['score'] as num? ?? 0).toInt(),
      alive: json['alive'] as bool? ?? false,
      color: (json['color'] as String? ?? '#F4D03F').trim(),
      pokemonId: (json['pokemonId'] as String? ?? '').trim(),
    );
  }
}

// ─── BattleRoyale: Wall ───────────────────────────────────────────────────────

class BattleRoyaleWall {
  final double x;
  final double y;
  final double w;
  final double h;

  const BattleRoyaleWall({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory BattleRoyaleWall.fromJson(Map<String, dynamic> json) {
    return BattleRoyaleWall(
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      w: (json['w'] as num? ?? 0).toDouble(),
      h: (json['h'] as num? ?? 0).toDouble(),
    );
  }
}

// ─── Static player data (snapshot) ───────────────────────────────────────────

class _PlayerStaticData {
  final String id;
  final String name;
  final double width;
  final double height;
  final int joinOrder;
  final String color;
  final String pokemonId;
  final String element;

  const _PlayerStaticData({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.joinOrder,
    required this.color,
    required this.pokemonId,
    required this.element,
  });
}

class _PlayerDynamicData {
  final String id;
  final double x;
  final double y;
  final int health;
  final int maxHealth;
  final bool alive;
  final String direction;
  final String facing;
  final int kills;
  final int score;

  const _PlayerDynamicData({
    required this.id,
    required this.x,
    required this.y,
    required this.health,
    required this.maxHealth,
    required this.alive,
    required this.direction,
    required this.facing,
    required this.kills,
    required this.score,
  });
}

// ─── AppData ──────────────────────────────────────────────────────────────────

class AppData extends ChangeNotifier {
  final WebSocketsHandler _wsHandler = WebSocketsHandler();
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectDelay = const Duration(seconds: 3);

  NetworkConfig networkConfig;
  String playerName;

  bool isConnected = false;
  bool isConnecting = false;
  String? playerId;
  MatchPhase phase = MatchPhase.connecting;
  int countdownSeconds = 0;
  String? winnerId;
  String winnerName = '';

  // World config from snapshot
  double worldWidth = 800;
  double worldHeight = 600;
  List<BattleRoyaleWall> walls = const <BattleRoyaleWall>[];

  // Dynamic state
  List<MultiplayerPlayer> players = const <MultiplayerPlayer>[];
  List<BattleRoyaleBullet> bullets = const <BattleRoyaleBullet>[];
  List<BattleRoyaleHealthItem> healthItems = const <BattleRoyaleHealthItem>[];
  List<PokemonInfo> pokemonList = const <PokemonInfo>[];  // Available Pokémon from server
  List<RankingEntry> ranking = const <RankingEntry>[];

  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;
  bool _disposed = false;
  String _lastDirection = 'none';
  Map<String, _PlayerStaticData> _playerStaticById = const <String, _PlayerStaticData>{};
  Map<String, _PlayerDynamicData> _playerDynamicById = const <String, _PlayerDynamicData>{};

  AppData({NetworkConfig initialConfig = NetworkConfig.defaults})
      : networkConfig = initialConfig,
        playerName = initialConfig.playerName {
    _connectToWebSocket();
  }

  MultiplayerPlayer? get localPlayer {
    final String? id = playerId;
    if (id == null || id.isEmpty) return null;
    for (final MultiplayerPlayer player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  List<MultiplayerPlayer> get sortedPlayers {
    final List<MultiplayerPlayer> sorted = List<MultiplayerPlayer>.from(players);
    sorted.sort((MultiplayerPlayer a, MultiplayerPlayer b) {
      // Alive players first
      if (a.alive != b.alive) return a.alive ? -1 : 1;
      return b.score.compareTo(a.score);
    });
    return sorted;
  }

  bool get canMove => isConnected && phase == MatchPhase.playing;
  bool get canRequestMatchRestart => isConnected && phase == MatchPhase.finished;

  void updateNetworkConfig(NetworkConfig nextConfig) {
    networkConfig = nextConfig;
    playerName = nextConfig.playerName;
    _reconnectAttempts = 0;
    playerId = null;
    _lastDirection = 'none';
    disconnect();
    _connectToWebSocket();
  }

  void updateMovementDirection(String direction) {
    final String normalized = _normalizeDirection(direction);
    if (_lastDirection == normalized) return;
    _lastDirection = normalized;
    _sendMessage(<String, dynamic>{'type': 'direction', 'value': normalized});
  }

  void sendShoot(double angle) {
    if (!canMove) return;
    _sendMessage(<String, dynamic>{'type': 'shoot', 'angle': angle});
  }

  // Shoot in the direction the Pokémon is already facing (no angle needed)
  void sendShootFacing() {
    if (!canMove) return;
    _sendMessage(<String, dynamic>{'type': 'shoot'});
  }

  void sendPokemonSelection(String pokemonId) {
    if (!isConnected) return;
    _sendMessage(<String, dynamic>{'type': 'selectPokemon', 'pokemonId': pokemonId});
  }

  void requestMatchRestart() {
    if (!canRequestMatchRestart) return;
    _sendMessage(<String, dynamic>{'type': 'restartMatch'});
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _lastDirection = 'none';
    _wsHandler.disconnectFromServer();
    isConnected = false;
    isConnecting = false;
    players = const <MultiplayerPlayer>[];
    bullets = const <BattleRoyaleBullet>[];
    healthItems = const <BattleRoyaleHealthItem>[];
    ranking = const <RankingEntry>[];
    _playerStaticById = const <String, _PlayerStaticData>{};
    _playerDynamicById = const <String, _PlayerDynamicData>{};
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }

  void _connectToWebSocket() {
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _intentionalDisconnect = false;
    isConnecting = true;
    isConnected = false;
    phase = MatchPhase.connecting;
    notifyListeners();

    _wsHandler.connectToServer(
      networkConfig.serverHost,
      networkConfig.serverPort,
      _onWebSocketMessage,
      useSecureSocket: networkConfig.useSecureWebSocket,
      onError: _onWebSocketError,
      onDone: _onWebSocketClosed,
    );
  }

  void _onWebSocketMessage(String message) {
    try {
      final Object? decoded = jsonDecode(message);
      if (decoded is! Map) return;
      final Map<String, dynamic> data = _mapFromDynamic(decoded);

      final String type = (data['type'] as String? ?? '').trim();

      if (type == 'welcome') {
        playerId = _wsHandler.socketId;
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        _registerPlayer();
        notifyListeners();
        return;
      }

      if (type == 'snapshot') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawSnapshot = data['snapshot'];
        _applySnapshot(rawSnapshot is Map ? _mapFromDynamic(rawSnapshot) : {});
        notifyListeners();
        return;
      }

      if (type == 'gameplay') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawState = data['gameState'];
        _applyGameplayState(rawState is Map ? _mapFromDynamic(rawState) : {});
        notifyListeners();
        return;
      }

      if (type == 'update') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawState = data['gameState'];
        final Map<String, dynamic> state = rawState is Map ? _mapFromDynamic(rawState) : {};
        _applySnapshot(state);
        _applyGameplayState(state);
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error processant missatge WebSocket: $error');
      }
    }
  }

  void _applySnapshot(Map<String, dynamic> state) {
    if (state.containsKey('worldWidth')) {
      worldWidth = (state['worldWidth'] as num? ?? 800).toDouble();
    }
    if (state.containsKey('worldHeight')) {
      worldHeight = (state['worldHeight'] as num? ?? 600).toDouble();
    }
    if (state.containsKey('walls')) {
      final List<dynamic> rawWalls = state['walls'] as List<dynamic>? ?? [];
      walls = rawWalls
          .whereType<Map>()
          .map((Map w) => BattleRoyaleWall.fromJson(_mapFromDynamic(w)))
          .toList(growable: false);
    }

    if (state.containsKey('pokemonList')) {
      final List<dynamic> rawPokemon = state['pokemonList'] as List<dynamic>? ?? [];
      pokemonList = rawPokemon
          .whereType<Map>()
          .map((Map p) => PokemonInfo.fromJson(_mapFromDynamic(p)))
          .toList(growable: false);
    }

    if (state.containsKey('players')) {
      final List<dynamic> rawPlayers = state['players'] as List<dynamic>? ?? [];
      _playerStaticById = <String, _PlayerStaticData>{
        for (final Map rawPlayer in rawPlayers.whereType<Map>())
          (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
              _staticPlayerFromJson(_mapFromDynamic(rawPlayer)),
      }..remove('');
      _playerDynamicById = Map<String, _PlayerDynamicData>.fromEntries(
        _playerDynamicById.entries.where(
          (MapEntry<String, _PlayerDynamicData> entry) =>
              _playerStaticById.containsKey(entry.key),
        ),
      );
    }

    _rebuildPlayers();
  }

  void _applyGameplayState(Map<String, dynamic> state) {
    phase = _parsePhase(state['phase'] as String?);
    countdownSeconds = (state['countdownSeconds'] as num? ?? 0).toInt();
    winnerId = state['winnerId'] as String?;
    winnerName = (state['winnerName'] as String? ?? '').trim();

    // Update dynamic player data
    final Map<String, _PlayerDynamicData> nextDynamic =
        Map<String, _PlayerDynamicData>.from(_playerDynamicById);

    final Object? rawSelf = state['selfPlayer'];
    if (rawSelf is Map) {
      final Map<String, dynamic> selfMap = _mapFromDynamic(rawSelf);
      final String selfId = (selfMap['id'] as String? ?? '').trim();
      if (selfId.isNotEmpty) {
        nextDynamic[selfId] = _dynamicPlayerFromJson(selfMap);
      }
    }

    if (state.containsKey('otherPlayers')) {
      final String currentId = (playerId ?? '').trim();
      nextDynamic.removeWhere(
        (String id, _PlayerDynamicData _) => id != currentId,
      );
      final List<dynamic> rawOthers = state['otherPlayers'] as List<dynamic>? ?? [];
      for (final Map rawPlayer in rawOthers.whereType<Map>()) {
        final Map<String, dynamic> parsed = _mapFromDynamic(rawPlayer);
        final String id = (parsed['id'] as String? ?? '').trim();
        if (id.isNotEmpty) {
          nextDynamic[id] = _dynamicPlayerFromJson(parsed);
        }
      }
    }

    _playerDynamicById = nextDynamic;
    _rebuildPlayers();

    // Bullets
    if (state.containsKey('bullets')) {
      final List<dynamic> rawBullets = state['bullets'] as List<dynamic>? ?? [];
      bullets = rawBullets
          .whereType<Map>()
          .map((Map b) => BattleRoyaleBullet.fromJson(_mapFromDynamic(b)))
          .toList(growable: false);
    }

    // Health items (server sends as 'healthItems' or 'gems')
    if (state.containsKey('healthItems')) {
      final List<dynamic> rawItems = state['healthItems'] as List<dynamic>? ?? [];
      healthItems = rawItems
          .whereType<Map>()
          .map((Map i) => BattleRoyaleHealthItem.fromJson(_mapFromDynamic(i)))
          .toList(growable: false);
    }

    // Ranking
    if (state.containsKey('ranking')) {
      final List<dynamic> rawRanking = state['ranking'] as List<dynamic>? ?? [];
      ranking = rawRanking
          .whereType<Map>()
          .map((Map r) => RankingEntry.fromJson(_mapFromDynamic(r)))
          .toList(growable: false);
    }
  }

  _PlayerStaticData _staticPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerStaticData(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      width: (json['width'] as num? ?? 32).toDouble(),
      height: (json['height'] as num? ?? 32).toDouble(),
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
      color: (json['color'] as String? ?? '#F4D03F').trim(),
      pokemonId: (json['pokemonId'] as String? ?? 'pikachu').trim(),
      element: (json['element'] as String? ?? 'normal').trim(),
    );
  }

  _PlayerDynamicData _dynamicPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerDynamicData(
      id: (json['id'] as String? ?? '').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      health: (json['health'] as num? ?? 100).toInt(),
      maxHealth: (json['maxHealth'] as num? ?? 100).toInt(),
      alive: json['alive'] as bool? ?? true,
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      score: (json['score'] as num? ?? 0).toInt(),
    );
  }

  void _rebuildPlayers() {
    final Set<String> ids = <String>{
      ..._playerStaticById.keys,
      ..._playerDynamicById.keys,
    };
    players = ids.map((String id) {
      final _PlayerStaticData? s = _playerStaticById[id];
      final _PlayerDynamicData? d = _playerDynamicById[id];
      return MultiplayerPlayer(
        id: id,
        name: s?.name ?? 'Player',
        x: d?.x ?? 0,
        y: d?.y ?? 0,
        width: s?.width ?? 32,
        height: s?.height ?? 32,
        health: d?.health ?? 100,
        maxHealth: d?.maxHealth ?? 100,
        alive: d?.alive ?? true,
        direction: d?.direction ?? 'none',
        facing: d?.facing ?? 'down',
        color: s?.color ?? '#F4D03F',
        kills: d?.kills ?? 0,
        score: d?.score ?? 0,
        joinOrder: s?.joinOrder ?? 0,
        pokemonId: s?.pokemonId ?? 'pikachu',
        element: s?.element ?? 'normal',
      );
    }).toList(growable: false);
  }

  void _registerPlayer() {
    _sendMessage(<String, dynamic>{
      'type': 'register',
      'playerName': playerName,
    });
  }

  void _onWebSocketError(dynamic error) {
    if (kDebugMode) print('Error de WebSocket: $error');
    isConnected = false;
    isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onWebSocketClosed() {
    if (kDebugMode) print('WebSocket tancat. Intentant reconnectar...');
    isConnected = false;
    isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    Future<void>.delayed(_reconnectDelay, () {
      if (_intentionalDisconnect || _disposed) return;
      _connectToWebSocket();
    });
  }

  void _sendMessage(Map<String, dynamic> payload) {
    if (_intentionalDisconnect ||
        _wsHandler.connectionStatus != ConnectionStatus.connected) {
      return;
    }
    _wsHandler.sendMessage(jsonEncode(payload));
  }

  MatchPhase _parsePhase(String? rawPhase) {
    switch ((rawPhase ?? '').trim().toLowerCase()) {
      case 'waiting':
        return MatchPhase.waiting;
      case 'playing':
        return MatchPhase.playing;
      case 'finished':
        return MatchPhase.finished;
      default:
        return MatchPhase.connecting;
    }
  }

  String _normalizeDirection(String rawDirection) {
    const List<String> valid = <String>[
      'up', 'upLeft', 'left', 'downLeft',
      'down', 'downRight', 'right', 'upRight', 'none',
    ];
    final String trimmed = rawDirection.trim();
    return valid.contains(trimmed) ? trimmed : 'none';
  }

  Map<String, dynamic> _mapFromDynamic(Map<dynamic, dynamic> raw) {
    return raw.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
}
