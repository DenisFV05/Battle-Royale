import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';

import 'app_data.dart';
import 'effects.dart';
import 'game_app.dart';
import 'level_data.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'pokemon_sprites.dart';
import 'waiting_room_screen.dart';

// ─── BattleRoyale Play Screen ─────────────────────────────────────────────────
// Renders Pokémon (colored boxes with name) instead of tanks.
// Space = shoot in facing direction. WASD = move.

class PlayScreen extends ScreenAdapter {
  static const double leaderboardWidth   = 240;
  static const double leaderboardPadding = 12;

  static final ui.Color bgColor         = const ui.Color(0xFFA9DFBF); // Original meadow green
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

  // Sprite animation state per player
  final Map<String, _PlayerAnim> _playerAnims = {};

  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _musicStarted = false;

  PlayScreen(this.game);

  @override
  void render(double delta) {
    _gameTime += delta;
    final AppData appData = game.getAppData();

    if (appData.phase == MatchPhase.waiting ||
        appData.phase == MatchPhase.connecting) {
      _stopMusic();
      _submitDirection(appData, 'none');
      _effects.clear();
      _previouslyAlive.clear();
      game.setScreen(WaitingRoomScreen(game));
      return;
    }

    if (!_musicStarted && appData.phase == MatchPhase.playing) {
      _startMusic();
    }

    final double screenW  = Gdx.graphics.getWidth().toDouble();
    final double screenH  = Gdx.graphics.getHeight().toDouble();
    final double gameAreaW = screenW - leaderboardWidth;

    _updateWorldTransform(appData, screenW, screenH);

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

    _renderMapLayers(canvas, appData);

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

  // ─── Tilemap Layers ───────────────────────────────────────────────────────

  void _renderMapLayers(ui.Canvas canvas, AppData appData) {
    final LevelData? level = appData.levelData;
    if (level == null) return;

    // Draw from bottom to top (in JSON, the first layer is the topmost one)
    for (int i = level.layers.size - 1; i >= 0; i--) {
      final LevelLayer layer = level.layers.get(i);
      if (!layer.visible) continue;
      
      final String path = layer.tilesTexturePath;
      if (!game.getAssetManager().isLoaded(path, Texture)) continue;
      final Texture tileset = game.getAssetManager().get(path, Texture);
      
      final int colsInTexture = tileset.width ~/ layer.tileWidth;
      
      for (int row = 0; row < layer.tileMap.length; row++) {
        final List<int> rowData = layer.tileMap[row];
        for (int col = 0; col < rowData.length; col++) {
          final int tileIndex = rowData[col];
          if (tileIndex < 0) continue; // Empty tile
          
          final double dstX = layer.x + col * layer.tileWidth;
          final double dstY = layer.y + row * layer.tileHeight;
          
          final int srcCol = tileIndex % colsInTexture;
          final int srcRow = tileIndex ~/ colsInTexture;
          
          // Inset by 0.05 to prevent texture bleeding (rayas raras) with fractional scaling
          final ui.Rect src = ui.Rect.fromLTWH(
            (srcCol * layer.tileWidth).toDouble() + 0.05,
            (srcRow * layer.tileHeight).toDouble() + 0.05,
            layer.tileWidth.toDouble() - 0.1,
            layer.tileHeight.toDouble() - 0.1,
          );
          
          final ui.Rect dst = ui.Rect.fromLTWH(
            dstX, 
            dstY, 
            layer.tileWidth.toDouble(), 
            layer.tileHeight.toDouble()
          );
          
          canvas.drawImageRect(
            tileset.image, 
            src, 
            dst, 
            ui.Paint()..filterQuality = ui.FilterQuality.none
          );
        }
      }
    }
  }

  // ─── Health Items ─────────────────────────────────────────────────────────

  void _renderHealthItems(ShapeRenderer shapes, AppData appData) {
    final double pulse = 1.0 + math.sin(_gameTime * 3.0) * 0.12;
    final ui.Canvas canvas = Gdx.graphics.getCanvas();
    final ui.Image? gemImg = PokemonSpriteRegistry.instance.gem;

    // Gem spritesheet: 5 cols × 4 rows of colored gems
    final double gemFW = gemImg != null ? gemImg.width  / 5.0 : 0;
    final double gemFH = gemImg != null ? gemImg.height / 4.0 : 0;

    for (final BattleRoyaleHealthItem item in appData.healthItems) {
      final double cx   = item.x + item.width  / 2;
      final double cy   = item.y + item.height / 2;
      final double size = item.width * pulse;

      // Soft glow
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x332ECC71));
      shapes.circle(cx, cy, size * 0.72, 12);
      shapes.end();

      if (gemImg != null) {
        // Draw green gem (col=1, row=0 — second gem is green)
        final ui.Rect src = ui.Rect.fromLTWH(gemFW, 0, gemFW, gemFH);
        final ui.Rect dst = ui.Rect.fromCenter(
          center: ui.Offset(cx, cy),
          width:  size * 1.1,
          height: size * 1.1,
        );
        canvas.drawImageRect(
          gemImg, src, dst,
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
      } else {
        final double arm   = size * 0.35;
        final double thick = size * 0.18;
        shapes.begin(ShapeType.filled);
        shapes.setColor(const ui.Color(0xFF2ECC71));
        shapes.rect(cx - thick, cy - arm, thick * 2, arm * 2);
        shapes.rect(cx - arm, cy - thick, arm * 2, thick * 2);
        shapes.end();
      }
    }
  }

  // ─── Pokémon Players (sprite-based) ─────────────────────────────────────────

  void _renderPlayers(ShapeRenderer shapes, AppData appData) {
    final String? localId = appData.playerId;
    final ui.Canvas canvas = Gdx.graphics.getCanvas();
    final PokemonSpriteRegistry reg = PokemonSpriteRegistry.instance;

    for (final MultiplayerPlayer player in appData.players) {
      if (!player.alive) continue;

      final bool isLocal   = player.id == localId;
      final bool isFlashing = _damageTracker.isFlashing(player.id, _gameTime);

      final double x = player.x;
      final double y = player.y;
      final double w = player.width;
      final double h = player.height;

      // Animate sprite frame
      _playerAnims.putIfAbsent(player.id, () => _PlayerAnim());
      final _PlayerAnim anim = _playerAnims[player.id]!;
      anim.update(_gameTime, player.direction);

      final PokemonSpriteBundle? bundle = reg.get(player.pokemonId);

      if (bundle != null) {
        // Choose sheet: hurt if flashing, walk if moving, idle if still
        final bool moving = player.direction != 'none' && player.direction.isNotEmpty;
        SheetInfo sheet;
        if (isFlashing) {
          sheet = bundle.hurt;
        } else if (moving) {
          sheet = bundle.walk;
        } else {
          sheet = bundle.idle;
        }

        final int row = facingToRow(player.facing);
        final int col = anim.frame % sheet.cols;

        // Draw shadow ellipse
        shapes.begin(ShapeType.filled);
        shapes.setColor(const ui.Color(0x33000000));
        shapes.circle(x + w / 2, y + h - 4, w * 0.35, 10);
        shapes.end();

        // Local player highlight ring
        if (isLocal) {
          shapes.begin(ShapeType.line);
          shapes.setColor(const ui.Color(0xFFFFE07A));
          shapes.rect(x - 3, y - 3, w + 6, h + 6);
          shapes.end();
        }

        // Draw sprite
        final ui.Rect dst = ui.Rect.fromLTWH(x, y, w, h);
        drawSpriteFrame(
          canvas: canvas,
          sheet: sheet,
          col: col,
          row: row,
          dstRect: dst,
          alpha: 1.0,
        );
      } else {
        // Fallback: colored box if sprites not loaded
        final ui.Color pokeColor = _parseColor(player.color);
        shapes.begin(ShapeType.filled);
        shapes.setColor(pokeColor.withAlpha(isLocal ? 230 : 180));
        shapes.rect(x, y, w, h);
        shapes.end();
      }

      // Health bar and name always rendered on top
      _renderHealthBar(shapes, player);
      _renderPlayerName(player, isLocal);
    }

    // Dead players — faint sprite or faded X
    for (final MultiplayerPlayer player in appData.players) {
      if (player.alive) continue;
      final double cx = player.x + player.width / 2;
      final double cy = player.y + player.height / 2;

      final PokemonSpriteBundle? bundle = reg.get(player.pokemonId);
      if (bundle != null) {
        final ui.Rect dst = ui.Rect.fromLTWH(player.x, player.y, player.width, player.height);
        drawSpriteFrame(
          canvas: canvas,
          sheet: bundle.faint,
          col: bundle.faint.cols - 1,
          row: facingToRow(player.facing),
          dstRect: dst,
          alpha: 0.45,
        );
      } else {
        final double r = player.width / 4;
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
    _musicPlayer.dispose();
    _submitDirection(game.getAppData(), 'none');
    _effects.clear();
  }

  void _startMusic() async {
    _musicStarted = true;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.15); // Suave, como pidió el usuario
      await _musicPlayer.play(AssetSource('other/music.mp3'));
    } catch (e) {
      // ignore: avoid_print
      print('Error al reproducir música: $e');
    }
  }

  void _stopMusic() {
    if (_musicStarted) {
      _musicPlayer.stop();
      _musicStarted = false;
    }
  }

  // ─── World transform ───────────────────────────────────────────────────────

  void _updateWorldTransform(AppData appData, double screenW, double screenH) {
    if (appData.worldWidth <= 0 || appData.worldHeight <= 0) return;

    final double gameAreaW = screenW - leaderboardWidth;
    final double scaleX = gameAreaW / appData.worldWidth;
    final double scaleY = screenH / appData.worldHeight;
    
    // Usamos Cover (max) para que no haya franjas, pero manteniendo proporciones
    _worldScale = math.max(scaleX, scaleY);
    
    final MultiplayerPlayer? self = appData.localPlayer;
    if (self != null) {
      // Centramos la cámara en el jugador, pero respecto al área de juego visible (izquierda del panel)
      _worldOffsetX = (gameAreaW / 2) - (self.x * _worldScale);
      _worldOffsetY = (screenH / 2) - (self.y * _worldScale);
    } else {
      _worldOffsetX = (gameAreaW - appData.worldWidth * _worldScale) / 2;
      _worldOffsetY = (screenH - appData.worldHeight * _worldScale) / 2;
    }

    // Limitamos el scroll para que la cámara no se salga de los bordes del mapa
    final double minOffsetX = gameAreaW - (appData.worldWidth * _worldScale);
    final double maxOffsetX = 0;
    final double minOffsetY = screenH - (appData.worldHeight * _worldScale);
    final double maxOffsetY = 0;

    if (minOffsetX < maxOffsetX) {
      _worldOffsetX = _worldOffsetX.clamp(minOffsetX, maxOffsetX);
    } else {
      _worldOffsetX = (gameAreaW - appData.worldWidth * _worldScale) / 2;
    }

    if (minOffsetY < maxOffsetY) {
      _worldOffsetY = _worldOffsetY.clamp(minOffsetY, maxOffsetY);
    } else {
      _worldOffsetY = (screenH - appData.worldHeight * _worldScale) / 2;
    }
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

// ─── Per-player animation state ───────────────────────────────────────────────
class _PlayerAnim {
  int frame = 0;

  /// Update frame index. Uses real game time so speed is framerate-independent.
  /// idle = 4 fps, moving = 6 fps.
  void update(double gameTime, String direction) {
    final bool moving = direction != 'none' && direction.isNotEmpty;
    final double fps = moving ? 6.0 : 4.0;
    frame = (gameTime * fps).floor();
  }
}
