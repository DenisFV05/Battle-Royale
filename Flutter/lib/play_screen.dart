import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'effects.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'waiting_room_screen.dart';

// ─── BattleRoyale Play Screen ─────────────────────────────────────────────────
// Renders the BattleRoyale game world: walls, tanks, bullets, health items.
// Uses ShapeRenderer for all drawing (no Games-Tool sprites needed).

class PlayScreen extends ScreenAdapter {
  static const double leaderboardWidth = 240;
  static const double leaderboardPadding = 12;

  // Colors — dark theme
  static final ui.Color bgColor = const ui.Color(0xFF0A0E1A);
  static final ui.Color gridColor = const ui.Color(0xFF151A2E);
  static final ui.Color wallColor = const ui.Color(0xFF3D4263);
  static final ui.Color wallHighlight = const ui.Color(0xFF525880);
  static final ui.Color healthItemColor = const ui.Color(0xFF2ECC71);
  static final ui.Color healthItemGlow = const ui.Color(0xFF27AE60);
  static final ui.Color bulletColor = const ui.Color(0xFFFFE07A);
  static final ui.Color bulletTrailColor = const ui.Color(0x44FFE07A);
  static final ui.Color healthBarBg = const ui.Color(0xFF1A1A2E);
  static final ui.Color healthBarFg = const ui.Color(0xFF2ECC71);
  static final ui.Color healthBarLow = const ui.Color(0xFFE74C3C);
  static final ui.Color panelBg = const ui.Color(0xCC080C14);
  static final ui.Color panelBorder = const ui.Color(0xFF58A6FF);
  static final ui.Color textColorTitle = const ui.Color(0xFFFFFFFF);
  static final ui.Color textColorDim = const ui.Color(0xFF8B949E);
  static final ui.Color overlayColor = const ui.Color(0xDD000000);
  static final ui.Color flashColor = const ui.Color(0xCCFFFFFF);

  final GameApp game;

  // World → screen mapping
  double _worldScale = 1.0;
  double _worldOffsetX = 0;
  double _worldOffsetY = 0;

  String _lastSubmittedDirection = 'none';

  // Effects
  final EffectsManager _effects = EffectsManager();
  final DamageTracker _damageTracker = DamageTracker();
  double _gameTime = 0;
  final Set<String> _previouslyAlive = {};

  PlayScreen(this.game);

  @override
  void render(double delta) {
    _gameTime += delta;
    final AppData appData = game.getAppData();

    // If waiting phase → go back to waiting room
    if (appData.phase == MatchPhase.waiting ||
        appData.phase == MatchPhase.connecting) {
      _submitDirection(appData, 'none');
      _effects.clear();
      _previouslyAlive.clear();
      game.setScreen(WaitingRoomScreen(game));
      return;
    }

    final double screenW = Gdx.graphics.getWidth().toDouble();
    final double screenH = Gdx.graphics.getHeight().toDouble();
    final double gameAreaW = screenW - leaderboardWidth;

    // Calculate world→screen scale
    _updateWorldTransform(appData, gameAreaW, screenH);

    // ── Track damage & deaths ──────────────────────────────────────────────
    for (final MultiplayerPlayer player in appData.players) {
      _damageTracker.update(player.id, player.health, _gameTime);

      // Detect death → spawn explosion
      if (_previouslyAlive.contains(player.id) && !player.alive) {
        _effects.add(ExplosionEffect(
          x: player.x + player.width / 2,
          y: player.y + player.height / 2,
          color: _parseColor(player.color),
          particleCount: 16,
          maxRadius: player.width * 1.5,
        ));
      }
    }
    _previouslyAlive.clear();
    for (final MultiplayerPlayer player in appData.players) {
      if (player.alive) _previouslyAlive.add(player.id);
    }

    // Update effects
    _effects.update(delta);

    // ── Input ──────────────────────────────────────────────────────────────
    _submitDirection(appData, _readCurrentDirection());
    _handleShootInput(appData);

    // ── Draw ───────────────────────────────────────────────────────────────
    final ShapeRenderer shapes = game.getShapeRenderer();

    // Full background
    shapes.begin(ShapeType.filled);
    shapes.setColor(bgColor);
    shapes.rect(0, 0, screenW, screenH);
    shapes.end();

    // Clip to game area (push transform)
    final ui.Canvas canvas = Gdx.graphics.getCanvas();
    canvas.save();
    canvas.translate(_worldOffsetX, _worldOffsetY);
    canvas.scale(_worldScale, _worldScale);

    // Grid
    _renderGrid(shapes, appData);

    // World border
    shapes.begin(ShapeType.line);
    shapes.setColor(const ui.Color(0xFF2A3050));
    shapes.rect(0, 0, appData.worldWidth, appData.worldHeight);
    shapes.end();

    // Walls (3D-ish with highlight)
    _renderWalls(shapes, appData);

    // Health items (pulsing cross)
    _renderHealthItems(shapes, appData);

    // Players (tank shape + health bars + names)
    _renderPlayers(shapes, appData);

    // Bullets with trails
    _renderBullets(shapes, appData);

    // Visual effects (explosions)
    _effects.render(shapes);

    // Restore canvas
    canvas.restore();

    // Ranking panel
    _renderRankingPanel(shapes, appData, gameAreaW, screenH);

    // Winner overlay
    if (appData.phase == MatchPhase.finished) {
      _renderWinnerOverlay(shapes, appData, gameAreaW, screenH);
    }
  }

  // ─── Grid Background ──────────────────────────────────────────────────────

  void _renderGrid(ShapeRenderer shapes, AppData appData) {
    const double gridSpacing = 40;
    shapes.begin(ShapeType.line);
    shapes.setColor(gridColor);
    for (double x = 0; x <= appData.worldWidth; x += gridSpacing) {
      shapes.line(x, 0, x, appData.worldHeight);
    }
    for (double y = 0; y <= appData.worldHeight; y += gridSpacing) {
      shapes.line(0, y, appData.worldWidth, y);
    }
    shapes.end();
  }

  // ─── Walls ────────────────────────────────────────────────────────────────

  void _renderWalls(ShapeRenderer shapes, AppData appData) {
    for (final BattleRoyaleWall wall in appData.walls) {
      // Shadow
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0xFF080A14));
      shapes.rect(wall.x + 3, wall.y + 3, wall.w, wall.h);
      shapes.end();

      // Body
      shapes.begin(ShapeType.filled);
      shapes.setColor(wallColor);
      shapes.rect(wall.x, wall.y, wall.w, wall.h);
      shapes.end();

      // Top highlight
      shapes.begin(ShapeType.filled);
      shapes.setColor(wallHighlight);
      shapes.rect(wall.x, wall.y, wall.w, math.min(4, wall.h));
      shapes.end();

      // Border
      shapes.begin(ShapeType.line);
      shapes.setColor(const ui.Color(0xFF5A6090));
      shapes.rect(wall.x, wall.y, wall.w, wall.h);
      shapes.end();
    }
  }

  // ─── Health Items ─────────────────────────────────────────────────────────

  void _renderHealthItems(ShapeRenderer shapes, AppData appData) {
    for (final BattleRoyaleHealthItem item in appData.healthItems) {
      final double cx = item.x + item.width / 2;
      final double cy = item.y + item.height / 2;

      // Pulsing scale
      final double pulse = 1.0 + math.sin(_gameTime * 3.0) * 0.12;
      final double arm = item.width * 0.35 * pulse;
      final double thick = item.width * 0.18 * pulse;

      // Glow circle behind
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x1A2ECC71));
      shapes.circle(cx, cy, item.width * 0.7 * pulse, 12);
      shapes.end();

      // Cross
      shapes.begin(ShapeType.filled);
      shapes.setColor(healthItemColor);
      shapes.rect(cx - thick, cy - arm, thick * 2, arm * 2);
      shapes.rect(cx - arm, cy - thick, arm * 2, thick * 2);
      shapes.end();

      // Border
      shapes.begin(ShapeType.line);
      shapes.setColor(healthItemGlow);
      shapes.rect(cx - thick, cy - arm, thick * 2, arm * 2);
      shapes.rect(cx - arm, cy - thick, arm * 2, thick * 2);
      shapes.end();
    }
  }

  // ─── Players (tank shape) ─────────────────────────────────────────────────

  void _renderPlayers(ShapeRenderer shapes, AppData appData) {
    final String? localId = appData.playerId;

    // Alive players
    for (final MultiplayerPlayer player in appData.players) {
      if (!player.alive) continue;

      final ui.Color tankColor = _parseColor(player.color);
      final bool isLocal = player.id == localId;
      final bool isFlashing = _damageTracker.isFlashing(player.id, _gameTime);

      final double cx = player.x + player.width / 2;
      final double cy = player.y + player.height / 2;
      final double halfW = player.width / 2;
      final double halfH = player.height / 2;
      final double angle = _directionToAngle(player.direction);

      // Tank shadow
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x33000000));
      shapes.circle(cx + 2, cy + 2, halfW * 0.85, 10);
      shapes.end();

      // Tank body (rounded look via circle)
      shapes.begin(ShapeType.filled);
      final ui.Color bodyColor = isFlashing ? flashColor : tankColor;
      shapes.setColor(bodyColor.withAlpha(isLocal ? 255 : 200));
      shapes.circle(cx, cy, halfW * 0.85, 12);
      shapes.end();

      // Tank inner circle (darker shade)
      shapes.begin(ShapeType.filled);
      shapes.setColor(isFlashing ? flashColor : _darken(tankColor, 0.3).withAlpha(isLocal ? 230 : 170));
      shapes.circle(cx, cy, halfW * 0.55, 10);
      shapes.end();

      // Turret / cannon — drawn as a thick line using canvas transform
      final double cannonLen = player.width * 0.8;
      final double cannonEndX = cx + math.cos(angle) * cannonLen;
      final double cannonEndY = cy + math.sin(angle) * cannonLen;
      final ui.Color cannonColor =
          isFlashing ? flashColor : _darken(tankColor, 0.15);
      // Draw cannon as thick rotated rect
      final ui.Canvas cannonCanvas = Gdx.graphics.getCanvas();
      cannonCanvas.save();
      cannonCanvas.translate(cx, cy);
      cannonCanvas.rotate(angle);
      final ui.Paint cannonPaint = ui.Paint()
        ..color = cannonColor
        ..style = ui.PaintingStyle.fill;
      cannonCanvas.drawRect(
        ui.Rect.fromLTWH(0, -3, cannonLen, 6),
        cannonPaint,
      );
      cannonCanvas.restore();

      // Cannon tip
      shapes.begin(ShapeType.filled);
      shapes.setColor(isFlashing ? flashColor : tankColor);
      shapes.circle(cannonEndX, cannonEndY, 3.5, 6);
      shapes.end();

      // Outline for local player
      if (isLocal) {
        shapes.begin(ShapeType.line);
        shapes.setColor(const ui.Color(0xFFFFE07A));
        shapes.circle(cx, cy, halfW + 3, 16);
        shapes.end();
      }

      // Name above tank
      _renderPlayerName(player, isLocal);

      // Health bar above player
      _renderHealthBar(shapes, player);
    }

    // Dead players (skull icon using shapes)
    for (final MultiplayerPlayer player in appData.players) {
      if (player.alive) continue;
      final double cx = player.x + player.width / 2;
      final double cy = player.y + player.height / 2;

      // Faded circle
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x22E74C3C));
      shapes.circle(cx, cy, player.width * 0.4, 10);
      shapes.end();

      // X mark
      final double r = player.width / 4;
      shapes.begin(ShapeType.line);
      shapes.setColor(const ui.Color(0x66E74C3C));
      shapes.line(cx - r, cy - r, cx + r, cy + r);
      shapes.line(cx + r, cy - r, cx - r, cy + r);
      shapes.end();
    }
  }

  void _renderPlayerName(MultiplayerPlayer player, bool isLocal) {
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();
    font.getData().setScale(0.6);
    font.setColor(isLocal ? const ui.Color(0xFFFFE07A) : const ui.Color(0xCCFFFFFF));
    final String name = player.name.length > 10
        ? player.name.substring(0, 10)
        : player.name;
    font.drawText(name, player.x - 5, player.y - 18);
    font.getData().setScale(1);
    batch.end();
  }

  void _renderHealthBar(ShapeRenderer shapes, MultiplayerPlayer player) {
    final double barW = player.width * 1.3;
    final double barH = 4.0;
    final double barX = player.x + (player.width - barW) / 2;
    final double barY = player.y - 10;
    final double hpRatio = player.maxHealth > 0
        ? (player.health / player.maxHealth).clamp(0.0, 1.0)
        : 0.0;

    // Background
    shapes.begin(ShapeType.filled);
    shapes.setColor(healthBarBg);
    shapes.rect(barX, barY, barW, barH);
    shapes.end();

    // Fill
    final ui.Color barColor = hpRatio > 0.4 ? healthBarFg : healthBarLow;
    shapes.begin(ShapeType.filled);
    shapes.setColor(barColor);
    shapes.rect(barX, barY, barW * hpRatio, barH);
    shapes.end();

    // Border
    shapes.begin(ShapeType.line);
    shapes.setColor(const ui.Color(0x44FFFFFF));
    shapes.rect(barX, barY, barW, barH);
    shapes.end();
  }

  // ─── Bullets ──────────────────────────────────────────────────────────────

  void _renderBullets(ShapeRenderer shapes, AppData appData) {
    for (final BattleRoyaleBullet bullet in appData.bullets) {
      // Trail glow
      shapes.begin(ShapeType.filled);
      shapes.setColor(bulletTrailColor);
      shapes.circle(bullet.x, bullet.y, bullet.size * 2.0, 8);
      shapes.end();

      // Bullet core
      shapes.begin(ShapeType.filled);
      shapes.setColor(bulletColor);
      shapes.circle(bullet.x, bullet.y, bullet.size, 8);
      shapes.end();

      // Bright center
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0xFFFFFFFF));
      shapes.circle(bullet.x, bullet.y, bullet.size * 0.4, 6);
      shapes.end();
    }
  }

  // ─── Ranking Panel ────────────────────────────────────────────────────────

  void _renderRankingPanel(
    ShapeRenderer shapes,
    AppData appData,
    double gameAreaW,
    double screenH,
  ) {
    final double panelX = gameAreaW;

    // Panel background
    shapes.begin(ShapeType.filled);
    shapes.setColor(panelBg);
    shapes.rect(panelX, 0, leaderboardWidth, screenH);
    shapes.end();

    // Separator line
    shapes.begin(ShapeType.line);
    shapes.setColor(panelBorder);
    shapes.line(panelX, 0, panelX, screenH);
    shapes.end();

    // Draw text
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();

    // Title
    font.getData().setScale(1.2);
    font.setColor(textColorTitle);
    font.drawText('⚔ BattleRoyale', panelX + leaderboardPadding, 28);

    // Phase indicator
    font.getData().setScale(0.85);
    final String phaseText = appData.phase == MatchPhase.playing
        ? '🟢 En partida'
        : appData.phase == MatchPhase.waiting
            ? '⏳ Esperant... ${appData.countdownSeconds}s'
            : appData.phase == MatchPhase.finished
                ? '🏆 Finalitzat'
                : '🔄 Connectant...';
    font.setColor(textColorDim);
    font.drawText(phaseText, panelX + leaderboardPadding, 50);

    // Separator
    font.getData().setScale(0.7);
    font.setColor(const ui.Color(0xFF3A4466));
    font.drawText('────────────────', panelX + leaderboardPadding, 68);

    // Ranking entries
    font.getData().setScale(0.9);
    double rowY = 88;
    for (final RankingEntry entry in appData.ranking) {
      final String prefix = entry.alive ? '🔴' : '💀';
      final String displayName = entry.name.length > 10
          ? entry.name.substring(0, 10)
          : entry.name;
      final String line = '#${entry.rank} $prefix $displayName';

      final bool isLocal = entry.id == appData.playerId;

      // Color indicator dot
      final ui.Color entryColor = _parseColor(entry.color);
      shapes.begin(ShapeType.filled);
      shapes.setColor(entryColor);
      shapes.circle(panelX + leaderboardPadding + 3, rowY - 4, 4, 8);
      shapes.end();

      batch.begin();
      font.setColor(isLocal ? const ui.Color(0xFFFFE07A) : textColorTitle);
      font.drawText(line, panelX + leaderboardPadding + 14, rowY);

      font.getData().setScale(0.72);
      font.setColor(textColorDim);
      font.drawText(
          'K:${entry.kills}  Pts:${entry.score}',
          panelX + leaderboardPadding + 28,
          rowY + 16);
      font.getData().setScale(0.9);
      batch.end();

      rowY += 44;
    }

    font.getData().setScale(1);
    batch.end();
  }

  // ─── Winner Overlay ───────────────────────────────────────────────────────

  void _renderWinnerOverlay(
    ShapeRenderer shapes,
    AppData appData,
    double gameAreaW,
    double screenH,
  ) {
    // Dark overlay
    shapes.begin(ShapeType.filled);
    shapes.setColor(overlayColor);
    shapes.rect(0, 0, gameAreaW, screenH);
    shapes.end();

    // Trophy decoration
    final double centerX = gameAreaW / 2;
    final double centerY = screenH * 0.35;

    // Glowing circle behind trophy
    final double glowPulse = 1.0 + math.sin(_gameTime * 2) * 0.1;
    shapes.begin(ShapeType.filled);
    shapes.setColor(const ui.Color(0x22FFE07A));
    shapes.circle(centerX, centerY, 80 * glowPulse, 20);
    shapes.end();
    shapes.begin(ShapeType.filled);
    shapes.setColor(const ui.Color(0x11FFE07A));
    shapes.circle(centerX, centerY, 120 * glowPulse, 20);
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();

    final String title = appData.winnerName.isNotEmpty
        ? '🏆 ${appData.winnerName} WINS!'
        : '🏆 Match Finished!';

    font.getData().setScale(2.2);
    font.setColor(const ui.Color(0xFFFFE07A));
    font.drawText(title, gameAreaW * 0.08, screenH * 0.44);

    font.getData().setScale(1.1);
    font.setColor(const ui.Color(0xFFD8FFE3));
    font.drawText('Press Restart to play again', gameAreaW * 0.18, screenH * 0.54);

    // Stats summary
    font.getData().setScale(0.9);
    font.setColor(textColorDim);
    double statY = screenH * 0.62;
    for (final RankingEntry entry in appData.ranking) {
      final String medal = entry.rank == 1 ? '🥇' : entry.rank == 2 ? '🥈' : entry.rank == 3 ? '🥉' : '  ';
      font.setColor(entry.rank <= 3 ? textColorTitle : textColorDim);
      font.drawText(
        '$medal ${entry.name} — ${entry.kills} kills, ${entry.score} pts',
        gameAreaW * 0.15,
        statY,
      );
      statY += 22;
      if (statY > screenH - 50) break;
    }

    font.getData().setScale(1);
    batch.end();
  }

  @override
  void resize(int width, int height) {
    // Will recalculate on next render
  }

  @override
  void dispose() {
    _submitDirection(game.getAppData(), 'none');
    _effects.clear();
  }

  // ─── World → Screen transform ──────────────────────────────────────────────

  void _updateWorldTransform(AppData appData, double areaW, double areaH) {
    if (appData.worldWidth <= 0 || appData.worldHeight <= 0) return;
    final double scaleX = areaW / appData.worldWidth;
    final double scaleY = areaH / appData.worldHeight;
    _worldScale = math.min(scaleX, scaleY);
    final double drawW = appData.worldWidth * _worldScale;
    final double drawH = appData.worldHeight * _worldScale;
    _worldOffsetX = (areaW - drawW) / 2;
    _worldOffsetY = (areaH - drawH) / 2;
  }

  // ─── Input ─────────────────────────────────────────────────────────────────

  void _submitDirection(AppData appData, String direction) {
    if (_lastSubmittedDirection == direction) return;
    _lastSubmittedDirection = direction;
    appData.updateMovementDirection(direction);
  }

  String _readCurrentDirection() {
    final bool left = Gdx.input.isKeyPressed(Input.keys.left) ||
        Gdx.input.isKeyPressed(Input.keys.a);
    final bool right = Gdx.input.isKeyPressed(Input.keys.right) ||
        Gdx.input.isKeyPressed(Input.keys.d);
    final bool up = Gdx.input.isKeyPressed(Input.keys.up) ||
        Gdx.input.isKeyPressed(Input.keys.w);
    final bool down = Gdx.input.isKeyPressed(Input.keys.down) ||
        Gdx.input.isKeyPressed(Input.keys.s);

    if (up && left) return 'upLeft';
    if (up && right) return 'upRight';
    if (down && left) return 'downLeft';
    if (down && right) return 'downRight';
    if (up) return 'up';
    if (down) return 'down';
    if (left) return 'left';
    if (right) return 'right';
    return 'none';
  }

  void _handleShootInput(AppData appData) {
    if (Gdx.input.justTouched()) {
      final MultiplayerPlayer? local = appData.localPlayer;
      if (local != null) {
        final double mx = Gdx.input.getX().toDouble();
        final double my = Gdx.input.getY().toDouble();

        // Convert mouse screen pos to world pos
        final double worldMouseX = (mx - _worldOffsetX) / _worldScale;
        final double worldMouseY = (my - _worldOffsetY) / _worldScale;

        final double playerCX = local.x + local.width / 2;
        final double playerCY = local.y + local.height / 2;

        final double angle = math.atan2(
          worldMouseY - playerCY,
          worldMouseX - playerCX,
        );
        appData.sendShoot(angle);
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double _directionToAngle(String direction) {
    switch (direction) {
      case 'right': return 0;
      case 'downRight': return math.pi / 4;
      case 'down': return math.pi / 2;
      case 'downLeft': return 3 * math.pi / 4;
      case 'left': return math.pi;
      case 'upLeft': return -3 * math.pi / 4;
      case 'up': return -math.pi / 2;
      case 'upRight': return -math.pi / 4;
      default: return 0;
    }
  }

  ui.Color _parseColor(String hexColor) {
    try {
      final String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) {
        final int value = int.parse(hex, radix: 16);
        return ui.Color(0xFF000000 | value);
      }
    } catch (_) {}
    return const ui.Color(0xFFE53935);
  }

  ui.Color _darken(ui.Color color, double amount) {
    final double factor = (1.0 - amount).clamp(0.0, 1.0);
    return ui.Color.fromARGB(
      color.alpha,
      (color.red * factor).round(),
      (color.green * factor).round(),
      (color.blue * factor).round(),
    );
  }
}
