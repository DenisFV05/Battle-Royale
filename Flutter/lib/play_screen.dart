import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'effects.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'waiting_room_screen.dart';

// ─── BattleRoyale Play Screen ─────────────────────────────────────────────────
// Renders Pokémon (colored boxes with name) instead of tanks.
// Space = shoot in facing direction. WASD = move.

class PlayScreen extends ScreenAdapter {
  static const double leaderboardWidth   = 240;
  static const double leaderboardPadding = 12;

  static final ui.Color bgColor         = const ui.Color(0xFFA9DFBF); // Light green meadow
  static final ui.Color gridColor       = const ui.Color(0xFF82E0AA); // Softer green grid
  static final ui.Color wallColor       = const ui.Color(0xFF8D6E63); // Brown walls
  static final ui.Color wallHighlight   = const ui.Color(0xFFA1887F);
  static final ui.Color healthBarBg     = const ui.Color(0x88000000);
  static final ui.Color healthBarFg     = const ui.Color(0xFF2ECC71);
  static final ui.Color healthBarLow    = const ui.Color(0xFFE74C3C);
  static final ui.Color panelBg         = const ui.Color(0xEEF0F4F8); // Light panel
  static final ui.Color panelBorder     = const ui.Color(0xFFBDC3C7);
  static final ui.Color textColorTitle  = const ui.Color(0xFF2C3E50); // Dark text
  static final ui.Color textColorDim    = const ui.Color(0xFF7F8C8D);
  static final ui.Color overlayColor    = const ui.Color(0xEEFFFFFF); // Light overlay
  static final ui.Color flashColor      = const ui.Color(0xCCFFFFFF);

  final GameApp game;

  double _worldScale   = 1.0;
  double _worldOffsetX = 0;
  double _worldOffsetY = 0;

  String _lastSubmittedDirection = 'none';
  bool   _lastSpaceWasDown       = false;

  final EffectsManager _effects      = EffectsManager();
  final DamageTracker  _damageTracker = DamageTracker();
  double _gameTime = 0;
  final Set<String> _previouslyAlive = {};

  PlayScreen(this.game);

  @override
  void render(double delta) {
    _gameTime += delta;
    final AppData appData = game.getAppData();

    if (appData.phase == MatchPhase.waiting ||
        appData.phase == MatchPhase.connecting) {
      _submitDirection(appData, 'none');
      _effects.clear();
      _previouslyAlive.clear();
      game.setScreen(WaitingRoomScreen(game));
      return;
    }

    final double screenW  = Gdx.graphics.getWidth().toDouble();
    final double screenH  = Gdx.graphics.getHeight().toDouble();
    final double gameAreaW = screenW - leaderboardWidth;

    _updateWorldTransform(appData, gameAreaW, screenH);

    // Track deaths → spawn faint effect
    for (final MultiplayerPlayer player in appData.players) {
      _damageTracker.update(player.id, player.health, _gameTime);
      if (_previouslyAlive.contains(player.id) && !player.alive) {
        _effects.add(ExplosionEffect(
          x: player.x + player.width / 2,
          y: player.y + player.height / 2,
          color: _parseColor(player.color),
          particleCount: 18,
          maxRadius: player.width * 1.8,
        ));
      }
    }
    _previouslyAlive.clear();
    for (final MultiplayerPlayer p in appData.players) {
      if (p.alive) _previouslyAlive.add(p.id);
    }

    _effects.update(delta);

    // Input
    _submitDirection(appData, _readCurrentDirection());
    _handleShootInput(appData);

    // Draw
    final ShapeRenderer shapes = game.getShapeRenderer();

    shapes.begin(ShapeType.filled);
    shapes.setColor(bgColor);
    shapes.rect(0, 0, screenW, screenH);
    shapes.end();

    final ui.Canvas canvas = Gdx.graphics.getCanvas();
    canvas.save();
    canvas.translate(_worldOffsetX, _worldOffsetY);
    canvas.scale(_worldScale, _worldScale);

    _renderGrid(shapes, appData);

    shapes.begin(ShapeType.line);
    shapes.setColor(const ui.Color(0xFF2A3050));
    shapes.rect(0, 0, appData.worldWidth, appData.worldHeight);
    shapes.end();

    _renderWalls(shapes, appData);
    _renderHealthItems(shapes, appData);
    _renderPlayers(shapes, appData);
    _renderBullets(shapes, appData);
    _effects.render(shapes);

    canvas.restore();

    _renderRankingPanel(shapes, appData, gameAreaW, screenH);

    if (appData.phase == MatchPhase.finished) {
      _renderWinnerOverlay(shapes, appData, gameAreaW, screenH);
    }
  }

  // ─── Grid ─────────────────────────────────────────────────────────────────

  void _renderGrid(ShapeRenderer shapes, AppData appData) {
    const double spacing = 40;
    shapes.begin(ShapeType.line);
    shapes.setColor(gridColor);
    for (double x = 0; x <= appData.worldWidth; x += spacing) {
      shapes.line(x, 0, x, appData.worldHeight);
    }
    for (double y = 0; y <= appData.worldHeight; y += spacing) {
      shapes.line(0, y, appData.worldWidth, y);
    }
    shapes.end();
  }

  // ─── Walls ────────────────────────────────────────────────────────────────

  void _renderWalls(ShapeRenderer shapes, AppData appData) {
    for (final BattleRoyaleWall wall in appData.walls) {
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x33000000));
      shapes.rect(wall.x + 3, wall.y + 3, wall.w, wall.h);
      shapes.end();

      shapes.begin(ShapeType.filled);
      shapes.setColor(wallColor);
      shapes.rect(wall.x, wall.y, wall.w, wall.h);
      shapes.end();

      shapes.begin(ShapeType.filled);
      shapes.setColor(wallHighlight);
      shapes.rect(wall.x, wall.y, wall.w, math.min(4, wall.h));
      shapes.end();

      shapes.begin(ShapeType.line);
      shapes.setColor(const ui.Color(0xFF6D4C41));
      shapes.rect(wall.x, wall.y, wall.w, wall.h);
      shapes.end();
    }
  }

  // ─── Health Items ─────────────────────────────────────────────────────────

  void _renderHealthItems(ShapeRenderer shapes, AppData appData) {
    final double pulse = 1.0 + math.sin(_gameTime * 3.0) * 0.12;
    for (final BattleRoyaleHealthItem item in appData.healthItems) {
      final double cx  = item.x + item.width / 2;
      final double cy  = item.y + item.height / 2;
      final double arm   = item.width * 0.35 * pulse;
      final double thick = item.width * 0.18 * pulse;

      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x1A2ECC71));
      shapes.circle(cx, cy, item.width * 0.7 * pulse, 12);
      shapes.end();

      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0xFF2ECC71));
      shapes.rect(cx - thick, cy - arm, thick * 2, arm * 2);
      shapes.rect(cx - arm, cy - thick, arm * 2, thick * 2);
      shapes.end();
    }
  }

  // ─── Pokémon Players (colored boxes) ──────────────────────────────────────

  void _renderPlayers(ShapeRenderer shapes, AppData appData) {
    final String? localId = appData.playerId;

    for (final MultiplayerPlayer player in appData.players) {
      if (!player.alive) continue;

      final ui.Color pokeColor  = _parseColor(player.color);
      final bool isLocal        = player.id == localId;
      final bool isFlashing     = _damageTracker.isFlashing(player.id, _gameTime);
      final ui.Color drawColor  = isFlashing ? flashColor : pokeColor;

      final double x = player.x;
      final double y = player.y;
      final double w = player.width;
      final double h = player.height;
      final double cx = x + w / 2;
      final double cy = y + h / 2;

      // Shadow
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x44000000));
      shapes.rect(x + 3, y + 3, w, h);
      shapes.end();

      // Main body box
      shapes.begin(ShapeType.filled);
      shapes.setColor(drawColor.withAlpha(isLocal ? 230 : 180));
      shapes.rect(x, y, w, h);
      shapes.end();

      // Inner lighter box (sprite placeholder centre)
      shapes.begin(ShapeType.filled);
      shapes.setColor(drawColor.withAlpha(isLocal ? 120 : 80));
      shapes.rect(x + 6, y + 6, w - 12, h - 12);
      shapes.end();

      // Facing direction arrow
      _renderFacingArrow(shapes, player, cx, cy, drawColor);

      // Outline for local player
      if (isLocal) {
        shapes.begin(ShapeType.line);
        shapes.setColor(const ui.Color(0xFFFFE07A));
        shapes.rect(x - 3, y - 3, w + 6, h + 6);
        shapes.end();
      }

      // Border
      shapes.begin(ShapeType.line);
      shapes.setColor(drawColor);
      shapes.rect(x, y, w, h);
      shapes.end();

      // Health bar
      _renderHealthBar(shapes, player);

      // Name label
      _renderPlayerName(player, isLocal);
    }

    // Dead players — faded X
    for (final MultiplayerPlayer player in appData.players) {
      if (player.alive) continue;
      final double cx = player.x + player.width / 2;
      final double cy = player.y + player.height / 2;
      final double r  = player.width / 4;

      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x22E74C3C));
      shapes.circle(cx, cy, player.width * 0.4, 10);
      shapes.end();

      shapes.begin(ShapeType.line);
      shapes.setColor(const ui.Color(0x66E74C3C));
      shapes.line(cx - r, cy - r, cx + r, cy + r);
      shapes.line(cx + r, cy - r, cx - r, cy + r);
      shapes.end();
    }
  }

  /// Small triangle arrow showing which direction the Pokémon faces.
  void _renderFacingArrow(
      ShapeRenderer shapes, MultiplayerPlayer player,
      double cx, double cy, ui.Color color) {
    final double arrowLen = player.width * 0.38;
    final double angle = _facingToAngle(player.facing);
    final double tipX = cx + math.cos(angle) * arrowLen;
    final double tipY = cy + math.sin(angle) * arrowLen;

    shapes.begin(ShapeType.line);
    shapes.setColor(color.withAlpha(200));
    shapes.line(cx, cy, tipX, tipY);
    shapes.end();

    // Arrow head
    shapes.begin(ShapeType.filled);
    shapes.setColor(color.withAlpha(200));
    shapes.circle(tipX, tipY, 4, 6);
    shapes.end();
  }

  void _renderPlayerName(MultiplayerPlayer player, bool isLocal) {
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font   = game.getFont();
    batch.begin();
    font.getData().setScale(0.65);
    font.setColor(isLocal ? const ui.Color(0xFFE74C3C) : const ui.Color(0xCC000000));
    // Show Pokémon name, not just player name
    final String label = player.pokemonId.isNotEmpty
        ? player.pokemonId[0].toUpperCase() + player.pokemonId.substring(1)
        : player.name;
    font.drawText(label, player.x - 4, player.y - 18);
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

    shapes.begin(ShapeType.filled);
    shapes.setColor(healthBarBg);
    shapes.rect(barX, barY, barW, barH);
    shapes.end();

    shapes.begin(ShapeType.filled);
    shapes.setColor(hpRatio > 0.4 ? healthBarFg : healthBarLow);
    shapes.rect(barX, barY, barW * hpRatio, barH);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(const ui.Color(0x44FFFFFF));
    shapes.rect(barX, barY, barW, barH);
    shapes.end();
  }

  // ─── Bullets (elemental coloured orbs) ───────────────────────────────────

  void _renderBullets(ShapeRenderer shapes, AppData appData) {
    for (final BattleRoyaleBullet bullet in appData.bullets) {
      final ui.Color elemColor = _elementColor(bullet.element);
      final ui.Color glowColor = elemColor.withAlpha(0x55);

      // Glow
      shapes.begin(ShapeType.filled);
      shapes.setColor(glowColor);
      shapes.circle(bullet.x, bullet.y, bullet.size * 2.2, 10);
      shapes.end();

      // Core
      shapes.begin(ShapeType.filled);
      shapes.setColor(elemColor);
      shapes.circle(bullet.x, bullet.y, bullet.size, 10);
      shapes.end();

      // Bright centre
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0xFFFFFFFF));
      shapes.circle(bullet.x, bullet.y, bullet.size * 0.4, 6);
      shapes.end();
    }
  }

  // ─── Ranking Panel ────────────────────────────────────────────────────────

  void _renderRankingPanel(ShapeRenderer shapes, AppData appData,
      double gameAreaW, double screenH) {
    final double panelX = gameAreaW;

    shapes.begin(ShapeType.filled);
    shapes.setColor(panelBg);
    shapes.rect(panelX, 0, leaderboardWidth, screenH);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(panelBorder);
    shapes.line(panelX, 0, panelX, screenH);
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font   = game.getFont();
    batch.begin();

    font.getData().setScale(1.1);
    font.setColor(textColorTitle);
    font.drawText('Pokemon Royale', panelX + leaderboardPadding, 28);

    font.getData().setScale(0.85);
    final String phaseText = appData.phase == MatchPhase.playing
        ? 'En partida'
        : appData.phase == MatchPhase.finished
            ? 'Finalitzat'
            : 'Esperant...';
    font.setColor(textColorDim);
    font.drawText(phaseText, panelX + leaderboardPadding, 50);

    font.getData().setScale(0.7);
    font.setColor(const ui.Color(0xFFBDC3C7));
    font.drawText('────────────────', panelX + leaderboardPadding, 68);

    font.getData().setScale(0.9);
    double rowY = 90;
    for (final RankingEntry entry in appData.ranking) {
      final String prefix      = entry.alive ? 'O' : 'X';
      final String displayName = entry.name.length > 10 ? entry.name.substring(0, 10) : entry.name;
      final String pokeName    = entry.pokemonId.isNotEmpty
          ? entry.pokemonId[0].toUpperCase() + entry.pokemonId.substring(1)
          : '???';

      final ui.Color entryColor = _parseColor(entry.color);
      shapes.begin(ShapeType.filled);
      shapes.setColor(entryColor);
      shapes.circle(panelX + leaderboardPadding + 4, rowY - 4, 4, 8);
      shapes.end();

      batch.begin();
      font.setColor(entry.id == appData.playerId
          ? const ui.Color(0xFFE74C3C)
          : textColorTitle);
      font.drawText('#${entry.rank} $prefix $pokeName', panelX + leaderboardPadding + 14, rowY);
      font.getData().setScale(0.72);
      font.setColor(textColorDim);
      font.drawText('K:${entry.kills}  Pts:${entry.score}', panelX + leaderboardPadding + 28, rowY + 16);
      font.getData().setScale(0.9);
      batch.end();

      rowY += 46;
    }

    font.getData().setScale(1);
    batch.end();
  }

  // ─── Winner Overlay ───────────────────────────────────────────────────────

  void _renderWinnerOverlay(ShapeRenderer shapes, AppData appData,
      double gameAreaW, double screenH) {
    shapes.begin(ShapeType.filled);
    shapes.setColor(overlayColor);
    shapes.rect(0, 0, gameAreaW, screenH);
    shapes.end();

    final double glow = 1.0 + math.sin(_gameTime * 2) * 0.1;
    shapes.begin(ShapeType.filled);
    shapes.setColor(const ui.Color(0x22F4D03F));
    shapes.circle(gameAreaW / 2, screenH * 0.38, 80 * glow, 20);
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font   = game.getFont();
    batch.begin();

    final String title = appData.winnerName.isNotEmpty
        ? '${appData.winnerName} ha guanyat!'
        : 'Partida finalitzada!';

    font.getData().setScale(2.2);
    font.setColor(const ui.Color(0xFFE74C3C));
    font.drawText(title, gameAreaW * 0.08, screenH * 0.44);

    font.getData().setScale(1.1);
    font.setColor(const ui.Color(0xFF2C3E50));
    font.drawText('Prem Restart per jugar de nou', gameAreaW * 0.18, screenH * 0.54);

    font.getData().setScale(0.9);
    double statY = screenH * 0.63;
    for (final RankingEntry entry in appData.ranking) {
      final String medal = entry.rank == 1 ? '#1' : entry.rank == 2 ? '#2' : entry.rank == 3 ? '#3' : '  ';
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
  void resize(int width, int height) {}

  @override
  void dispose() {
    _submitDirection(game.getAppData(), 'none');
    _effects.clear();
  }

  // ─── World transform ───────────────────────────────────────────────────────

  void _updateWorldTransform(AppData appData, double areaW, double areaH) {
    if (appData.worldWidth <= 0 || appData.worldHeight <= 0) return;
    final double scaleX = areaW / appData.worldWidth;
    final double scaleY = areaH / appData.worldHeight;
    _worldScale   = math.min(scaleX, scaleY);
    final double drawW = appData.worldWidth  * _worldScale;
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
    final bool left  = Gdx.input.isKeyPressed(Input.keys.left)  || Gdx.input.isKeyPressed(Input.keys.a);
    final bool right = Gdx.input.isKeyPressed(Input.keys.right) || Gdx.input.isKeyPressed(Input.keys.d);
    final bool up    = Gdx.input.isKeyPressed(Input.keys.up)    || Gdx.input.isKeyPressed(Input.keys.w);
    final bool down  = Gdx.input.isKeyPressed(Input.keys.down)  || Gdx.input.isKeyPressed(Input.keys.s);

    if (up && left)  return 'upLeft';
    if (up && right) return 'upRight';
    if (down && left)  return 'downLeft';
    if (down && right) return 'downRight';
    if (up)    return 'up';
    if (down)  return 'down';
    if (left)  return 'left';
    if (right) return 'right';
    return 'none';
  }

  /// Space bar shoots in the direction the Pokémon is facing.
  void _handleShootInput(AppData appData) {
    final bool spaceDown = Gdx.input.isKeyPressed(Input.keys.space);
    if (spaceDown && !_lastSpaceWasDown) {
      appData.sendShootFacing();
    }
    _lastSpaceWasDown = spaceDown;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double _facingToAngle(String facing) {
    switch (facing) {
      case 'right':      return 0;
      case 'downRight':  return math.pi / 4;
      case 'down':       return math.pi / 2;
      case 'downLeft':   return 3 * math.pi / 4;
      case 'left':       return math.pi;
      case 'upLeft':     return -3 * math.pi / 4;
      case 'up':         return -math.pi / 2;
      case 'upRight':    return -math.pi / 4;
      default:           return math.pi / 2;
    }
  }

  ui.Color _elementColor(String element) {
    switch (element) {
      case 'dragon':   return const ui.Color(0xFF7038F8);
      case 'water':    return const ui.Color(0xFF3498DB);
      case 'fire':     return const ui.Color(0xFFE74C3C);
      case 'ghost':    return const ui.Color(0xFF705898);
      case 'electric': return const ui.Color(0xFFF4D03F);
      case 'fighting': return const ui.Color(0xFFC03028);
      case 'rock':     return const ui.Color(0xFFB8A038);
      case 'grass':    return const ui.Color(0xFF2ECC71);
      case 'ice':      return const ui.Color(0xFF98D8D8);
      case 'ground':   return const ui.Color(0xFFE0C068);
      default:         return const ui.Color(0xFFBDC3C7);
    }
  }

  ui.Color _parseColor(String hexColor) {
    try {
      final String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) return ui.Color(0xFF000000 | int.parse(hex, radix: 16));
    } catch (_) {}
    return const ui.Color(0xFFE53935);
  }

  ui.Color _darken(ui.Color color, double amount) {
    final double f = (1.0 - amount).clamp(0.0, 1.0);
    return ui.Color.fromARGB(
      color.alpha,
      (color.red   * f).round(),
      (color.green * f).round(),
      (color.blue  * f).round(),
    );
  }
}
