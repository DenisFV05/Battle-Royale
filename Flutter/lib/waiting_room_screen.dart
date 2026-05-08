import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'play_screen.dart';

/// Waiting room shown while the server is counting down to match start.
/// Simplified: no Games-Tool level data, no gem sprites.
class WaitingRoomScreen extends ScreenAdapter {
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double panelWidth = 300;
  static const double panelPadding = 14;

  static final ui.Color background = colorValueOf('070E1A');
  static final ui.Color panelFill = colorValueOf('0D1117CC');
  static final ui.Color panelStroke = colorValueOf('58A6FF');
  static final ui.Color titleColor = colorValueOf('FFFFFF');
  static final ui.Color textColor = colorValueOf('C9D1D9');
  static final ui.Color dimTextColor = colorValueOf('8B949E');
  static final ui.Color highlightColor = colorValueOf('58A6FF');
  static final ui.Color localPlayerColor = colorValueOf('FFE07A');
  static final ui.Color aliveColor = colorValueOf('2ECC71');
  static final ui.Color deadColor = colorValueOf('E74C3C');

  final GameApp game;
  final Viewport viewport = FitViewport(
    worldWidth,
    worldHeight,
    OrthographicCamera(),
  );
  final GlyphLayout layout = GlyphLayout();
  double _elapsedSeconds = 0;

  WaitingRoomScreen(this.game);

  @override
  void render(double delta) {
    _elapsedSeconds += delta;
    final AppData appData = game.getAppData();

    if (appData.phase == MatchPhase.playing ||
        appData.phase == MatchPhase.finished) {
      game.setScreen(PlayScreen(game));
      return;
    }

    ScreenUtils.clear(background);
    viewport.apply();

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    // Main game area background
    shapes.begin(ShapeType.filled);
    shapes.setColor(const ui.Color(0xFF0D1117));
    shapes.rect(0, 0, worldWidth - panelWidth, worldHeight);
    shapes.end();

    // Right panel
    shapes.begin(ShapeType.filled);
    shapes.setColor(panelFill);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();
    shapes.begin(ShapeType.line);
    shapes.setColor(panelStroke);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();

    // Animated tanks preview (decorative)
    _drawDecorativeTanks(shapes, _elapsedSeconds);

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();

    // Title
    font.getData().setScale(3.2);
    font.setColor(titleColor);
    layout.setText(font, 'BattleRoyale');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.18);

    // Subtitle
    font.getData().setScale(1.4);
    font.setColor(dimTextColor);
    layout.setText(font, 'Match starts in');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.32);

    // Countdown
    font.getData().setScale(5.5);
    font.setColor(highlightColor);
    final String countdown = '${math.max(0, appData.countdownSeconds)}';
    layout.setText(font, countdown);
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.50);

    // Instructions
    font.getData().setScale(1.2);
    font.setColor(textColor);
    layout.setText(font, 'WASD = Move    Click = Shoot');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.64);

    font.getData().setScale(1.1);
    font.setColor(dimTextColor);
    layout.setText(font, 'Last tank standing wins!');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.73);

    // Right panel — player list
    font.getData().setScale(1.3);
    font.setColor(titleColor);
    font.drawText('Players', worldWidth - panelWidth + panelPadding, 30);

    font.getData().setScale(0.85);
    font.setColor(dimTextColor);
    font.drawText('Waiting for match...', worldWidth - panelWidth + panelPadding, 52);

    double rowY = 84;
    for (final MultiplayerPlayer player in appData.sortedPlayers) {
      final bool isLocal = player.id == appData.playerId;
      final ui.Color nameColor = isLocal ? localPlayerColor : textColor;
      font.getData().setScale(0.95);
      font.setColor(nameColor);
      font.drawText(
        '${isLocal ? "▶ " : "  "}${player.name.length > 14 ? player.name.substring(0, 14) : player.name}',
        worldWidth - panelWidth + panelPadding,
        rowY,
      );
      rowY += 28;
      if (rowY > worldHeight - 20) break;
    }

    if (appData.sortedPlayers.isEmpty) {
      font.getData().setScale(0.9);
      font.setColor(dimTextColor);
      font.drawText(
        'Connecting...',
        worldWidth - panelWidth + panelPadding,
        84,
      );
    }

    font.getData().setScale(1);
    batch.end();
  }

  void _drawDecorativeTanks(ShapeRenderer shapes, double t) {
    final double areaW = worldWidth - panelWidth;
    final double areaH = worldHeight;

    // Draw a few tanks moving in circles as decoration
    final List<Map<String, dynamic>> tanks = <Map<String, dynamic>>[
      <String, dynamic>{'cx': areaW * 0.3, 'cy': areaH * 0.5, 'r': 60.0, 'speed': 0.5, 'color': const ui.Color(0x44E53935)},
      <String, dynamic>{'cx': areaW * 0.6, 'cy': areaH * 0.5, 'r': 80.0, 'speed': -0.4, 'color': const ui.Color(0x441E88E5)},
      <String, dynamic>{'cx': areaW * 0.45, 'cy': areaH * 0.4, 'r': 50.0, 'speed': 0.7, 'color': const ui.Color(0x4443A047)},
    ];

    for (final Map<String, dynamic> tank in tanks) {
      final double cx = tank['cx'] as double;
      final double cy = tank['cy'] as double;
      final double r = tank['r'] as double;
      final double speed = tank['speed'] as double;
      final ui.Color color = tank['color'] as ui.Color;

      final double angle = t * speed;
      final double tx = cx + math.cos(angle) * r;
      final double ty = cy + math.sin(angle) * r;

      shapes.begin(ShapeType.filled);
      shapes.setColor(color);
      shapes.circle(tx, ty, 18, 12);
      shapes.end();
    }
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }
}
