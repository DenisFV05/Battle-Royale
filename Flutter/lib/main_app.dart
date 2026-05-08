import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/gdx.dart';
import 'network_config.dart';
import 'play_screen.dart';
import 'window_config.dart';

class MainApp {
  MainApp._();

  static Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await configureGameWindow('BattleRoyale — Multiplayer');
    runApp(const _GameRoot());
  }
}

class _GameRoot extends StatefulWidget {
  const _GameRoot();

  @override
  State<_GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<_GameRoot> {
  NetworkConfig? _networkConfig;

  void _handleStartGame(NetworkConfig config) {
    setState(() {
      _networkConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BattleRoyale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58A6FF),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontFamily: 'monospace', letterSpacing: 2),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF050A12),
        body: SafeArea(
          child: _networkConfig == null
              ? _ConfigurationScreen(onStart: _handleStartGame)
              : _GameView(networkConfig: _networkConfig!),
        ),
      ),
    );
  }
}

// ─── Premium Configuration Screen ────────────────────────────────────────────

class _ConfigurationScreen extends StatefulWidget {
  final ValueChanged<NetworkConfig> onStart;
  const _ConfigurationScreen({required this.onStart});

  @override
  State<_ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<_ConfigurationScreen>
    with SingleTickerProviderStateMixin {
  ServerOption _serverOption = ServerOption.local;
  final TextEditingController _nameCtrl =
      TextEditingController(text: NetworkConfig.defaults.playerName);
  final TextEditingController _hostCtrl =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _portCtrl =
      TextEditingController(text: '3000');
  String? _nameError;
  late AnimationController _animCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Cal introduir un nom de jugador');
      return;
    }
    setState(() => _nameError = null);

    int port = 3000;
    if (_serverOption == ServerOption.custom) {
      port = int.tryParse(_portCtrl.text.trim()) ?? 3000;
    }

    widget.onStart(NetworkConfig(
      serverOption: _serverOption,
      playerName: name,
      customHost: _hostCtrl.text.trim(),
      customPort: port,
    ));
  }

  Widget _buildServerLabel() {
    String label;
    switch (_serverOption) {
      case ServerOption.local:
        label = 'ws://127.0.0.1:3000';
        break;
      case ServerOption.proxmox:
        label =
            'ws://${NetworkConfig.proxmoxServer}:${NetworkConfig.proxmoxPort}';
        break;
      case ServerOption.custom:
        label =
            'ws://${_hostCtrl.text.isEmpty ? '...' : _hostCtrl.text}:${_portCtrl.text.isEmpty ? '...' : _portCtrl.text}';
        break;
    }
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: Color(0xFF58A6FF),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background
        Positioned.fill(child: _AnimatedBackground()),

        // Content
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Transform.scale(
                      scale: _pulse.value,
                      child: const Text(
                        '⚔ BATTLEROYALE',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFFFFE07A),
                          shadows: [
                            Shadow(
                                color: Color(0xFFFFE07A),
                                blurRadius: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Last Tank Standing',
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xCC0D1117),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF30363D),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4458A6FF),
                          blurRadius: 30,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Player name
                        const Text(
                          'NOM DE JUGADOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ex: Jugador1',
                            hintStyle: const TextStyle(
                                color: Color(0xFF444D56)),
                            errorText: _nameError,
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFF58A6FF), size: 20),
                            filled: true,
                            fillColor: const Color(0xFF0D1117),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF30363D)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF30363D)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: Color(0xFF58A6FF), width: 2),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(20),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Server selector
                        const Text(
                          'SERVIDOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ServerOptionSelector(
                          selected: _serverOption,
                          onChanged: (opt) =>
                              setState(() => _serverOption = opt),
                        ),
                        const SizedBox(height: 10),
                        _buildServerLabel(),

                        // Custom host/port fields
                        if (_serverOption == ServerOption.custom) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _hostCtrl,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 13),
                                  decoration: _fieldDecoration('IP / Host'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _portCtrl,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 13),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  decoration: _fieldDecoration('Port'),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Start button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58A6FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sports_esports, size: 20),
                                SizedBox(width: 10),
                                Text('CONNECTAR I JUGAR'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'WASD per moure • Clic esquerre per disparar',
                    style: TextStyle(
                      color: Color(0xFF444D56),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF0D1117),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFF58A6FF), width: 1.5),
      ),
    );
  }
}

// ─── Server Option Selector ───────────────────────────────────────────────────

class _ServerOptionSelector extends StatelessWidget {
  final ServerOption selected;
  final ValueChanged<ServerOption> onChanged;

  const _ServerOptionSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OptionChip(
          label: '🖥 Local',
          selected: selected == ServerOption.local,
          onTap: () => onChanged(ServerOption.local),
        ),
        const SizedBox(width: 8),
        _OptionChip(
          label: '🌐 Proxmox',
          selected: selected == ServerOption.proxmox,
          onTap: () => onChanged(ServerOption.proxmox),
        ),
        const SizedBox(width: 8),
        _OptionChip(
          label: '✏ Custom',
          selected: selected == ServerOption.custom,
          onTap: () => onChanged(ServerOption.custom),
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF58A6FF).withOpacity(0.15)
              : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF58A6FF)
                : const Color(0xFF30363D),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? const Color(0xFF58A6FF)
                : const Color(0xFF8B949E),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Background ──────────────────────────────────────────────────────

class _AnimatedBackground extends StatefulWidget {
  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_FloatingTank> _tanks = [];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    for (int i = 0; i < 8; i++) {
      _tanks.add(_FloatingTank(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.008 + _rng.nextDouble() * 0.012,
        angle: _rng.nextDouble() * math.pi * 2,
        size: 12 + _rng.nextDouble() * 20,
        color: [
          const Color(0x0CE53935),
          const Color(0x0C1E88E5),
          const Color(0x0C43A047),
          const Color(0x0CFB8C00),
          const Color(0x0C8E24AA),
        ][i % 5],
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BgPainter(_tanks, _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _FloatingTank {
  double x, y;
  final double speed, angle, size;
  final Color color;

  _FloatingTank({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.size,
    required this.color,
  });
}

class _BgPainter extends CustomPainter {
  final List<_FloatingTank> tanks;
  final double t;

  _BgPainter(this.tanks, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF050A12);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF0C1220)
      ..strokeWidth = 1;
    const double spacing = 50;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Floating tanks
    final paint = Paint()..style = PaintingStyle.fill;
    for (final tank in tanks) {
      final cx = (tank.x + math.cos(tank.angle) * t * tank.speed * 5) % 1.0;
      final cy = (tank.y + math.sin(tank.angle) * t * tank.speed * 5) % 1.0;
      paint.color = tank.color;
      canvas.drawCircle(
        Offset(cx * size.width, cy * size.height),
        tank.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Game View ────────────────────────────────────────────────────────────────

class _GameView extends StatefulWidget {
  final NetworkConfig networkConfig;
  const _GameView({required this.networkConfig});

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView>
    with SingleTickerProviderStateMixin {
  static const double _virtualWidth = 1280;
  static const double _virtualHeight = 720;

  final FocusNode _focusNode = FocusNode();
  late final GameApp _game;

  Ticker? _ticker;
  Duration? _lastTick;
  double _delta = 1 / 60;
  bool _ready = false;
  Size _surfaceSize = Size.zero;
  double _scale = 1;
  double _offsetX = 0;
  double _offsetY = 0;
  int _lastGameWidth = -1;
  int _lastGameHeight = -1;
  bool _lastLetterboxedMode = true;

  @override
  void initState() {
    super.initState();
    _game = GameApp(networkConfig: widget.networkConfig);
    _initialize();
  }

  Future<void> _initialize() async {
    await _game.create();
    _ticker = createTicker((Duration elapsed) {
      if (_lastTick == null) {
        _lastTick = elapsed;
      } else {
        final double dt =
            (elapsed - _lastTick!).inMicroseconds / 1000000.0;
        _delta = dt.isFinite && dt > 0 ? dt : (1 / 60);
        _lastTick = elapsed;
      }
      if (mounted) setState(() {});
    });
    _ticker!.start();
    if (mounted) {
      setState(() => _ready = true);
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _game.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final int? keycode = logicalKeyToGdxKey(event.logicalKey);
    if (keycode == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      Gdx.input.onKeyDown(keycode);
    } else if (event is KeyUpEvent) {
      Gdx.input.onKeyUp(keycode);
    }
    return KeyEventResult.handled;
  }

  bool _isLetterboxedMode() => _game.getScreen() is! PlayScreen;

  Offset? _toGameOffset(Offset localPosition) {
    if (_surfaceSize == Size.zero) return null;
    if (!_isLetterboxedMode()) {
      if (localPosition.dx < 0 ||
          localPosition.dy < 0 ||
          localPosition.dx > _surfaceSize.width ||
          localPosition.dy > _surfaceSize.height) return null;
      return localPosition;
    }
    final double x = (localPosition.dx - _offsetX) / _scale;
    final double y = (localPosition.dy - _offsetY) / _scale;
    if (x < 0 || y < 0 || x > _virtualWidth || y > _virtualHeight) {
      return null;
    }
    return Offset(x, y);
  }

  void _updateLetterbox(Size size) {
    final double sx = size.width / _virtualWidth;
    final double sy = size.height / _virtualHeight;
    _scale = math.min(sx, sy);
    final double drawWidth = _virtualWidth * _scale;
    final double drawHeight = _virtualHeight * _scale;
    _offsetX = (size.width - drawWidth) * 0.5;
    _offsetY = (size.height - drawHeight) * 0.5;
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) return;
    Gdx.input.onPointerDown(gameOffset.dx, gameOffset.dy);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) return;
    Gdx.input.onPointerMove(gameOffset.dx, gameOffset.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    final Offset? gameOffset = _toGameOffset(event.localPosition);
    if (gameOffset == null) return;
    Gdx.input.onPointerUp(gameOffset.dx, gameOffset.dy);
  }

  void _resizeGameIfNeeded(int width, int height, bool letterboxedMode) {
    if (width == _lastGameWidth &&
        height == _lastGameHeight &&
        letterboxedMode == _lastLetterboxedMode) return;
    _lastGameWidth = width;
    _lastGameHeight = height;
    _lastLetterboxedMode = letterboxedMode;
    _game.resize(width, height);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(color: Color(0xFF050A12));
    }

    final AppData appData = _game.getAppData();
    final bool showRestartOverlay =
        _game.getScreen() is PlayScreen &&
            appData.phase == MatchPhase.finished;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, KeyEvent event) => _onKeyEvent(event),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _surfaceSize =
              Size(constraints.maxWidth, constraints.maxHeight);
          if (_isLetterboxedMode()) {
            _updateLetterbox(_surfaceSize);
          } else {
            _scale = 1;
            _offsetX = 0;
            _offsetY = 0;
          }
          final double reservedRightWidth =
              constraints.maxWidth > (PlayScreen.leaderboardWidth + 180)
                  ? PlayScreen.leaderboardWidth
                  : 0;
          final double overlayAreaWidth = math.max(
              0, constraints.maxWidth - reservedRightWidth);
          final double restartButtonWidth =
              math.min(280, math.max(180, overlayAreaWidth - 48));
          final double restartButtonLeft =
              math.max(24, (overlayAreaWidth - restartButtonWidth) * 0.5);
          final double restartButtonTop = math.min(
              constraints.maxHeight - 84,
              constraints.maxHeight * 0.64);

          return Listener(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: CustomPaint(
                    painter: _GamePainter(
                      onPaint: (Canvas canvas, Size size) {
                        final bool letterboxedMode = _isLetterboxedMode();
                        final int gameWidth;
                        final int gameHeight;

                        if (letterboxedMode) {
                          _updateLetterbox(size);
                          gameWidth = _virtualWidth.round();
                          gameHeight = _virtualHeight.round();
                        } else {
                          _scale = 1;
                          _offsetX = 0;
                          _offsetY = 0;
                          gameWidth = math.max(1, size.width.round());
                          gameHeight = math.max(1, size.height.round());
                        }

                        _resizeGameIfNeeded(
                            gameWidth, gameHeight, letterboxedMode);

                        if (letterboxedMode) {
                          canvas.drawRect(
                            Offset.zero & size,
                            Paint()..color = const Color(0xFF050A12),
                          );
                          canvas.save();
                          canvas.translate(_offsetX, _offsetY);
                          canvas.scale(_scale, _scale);
                          Gdx.graphics
                              .beginFrame(canvas, gameWidth, gameHeight, _delta);
                          _game.render(_delta);
                          Gdx.graphics.endFrame();
                          canvas.restore();
                        } else {
                          Gdx.graphics
                              .beginFrame(canvas, gameWidth, gameHeight, _delta);
                          _game.render(_delta);
                          Gdx.graphics.endFrame();
                        }
                        Gdx.input.endFrame();
                      },
                    ),
                    size: Size.infinite,
                  ),
                ),
                if (showRestartOverlay)
                  Positioned(
                    left: restartButtonLeft,
                    top: restartButtonTop,
                    width: restartButtonWidth,
                    child: FilledButton.icon(
                      onPressed: appData.canRequestMatchRestart
                          ? appData.requestMatchRestart
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: const Text('REINICIAR PARTIDA'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF58A6FF),
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final void Function(Canvas canvas, Size size) onPaint;
  _GamePainter({required this.onPaint});

  @override
  void paint(Canvas canvas, Size size) => onPaint(canvas, size);

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
