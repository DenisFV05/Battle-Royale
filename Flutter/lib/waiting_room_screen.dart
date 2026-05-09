import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'play_screen.dart';

/// Waiting room shown while the server counts down.
/// Includes a Pokémon selector grid.
class WaitingRoomScreen extends ScreenAdapter {
  static const double worldWidth  = 1280;
  static const double worldHeight = 720;
  static const double panelWidth  = 300;
  static const double panelPadding = 14;

  // Pokémon grid layout
  static const double gridStartX  = 60;
  static const double gridStartY  = 300;
  static const double cellSize    = 88;
  static const double cellPad     = 12;
  static const int   gridCols     = 5;

  static final ui.Color background      = colorValueOf('070E1A');
  static final ui.Color panelFill       = colorValueOf('0D1117CC');
  static final ui.Color panelStroke     = colorValueOf('58A6FF');
  static final ui.Color titleColor      = colorValueOf('FFFFFF');
  static final ui.Color textColor       = colorValueOf('C9D1D9');
  static final ui.Color dimTextColor    = colorValueOf('8B949E');
  static final ui.Color highlightColor  = colorValueOf('58A6FF');
  static final ui.Color localPlayerColor = colorValueOf('FFE07A');
  static final ui.Color selectedBorder  = colorValueOf('FFE07A');
  static final ui.Color hoverBorder     = colorValueOf('58A6FF');

  final GameApp game;
  final Viewport viewport = FitViewport(worldWidth, worldHeight, OrthographicCamera());
  final GlyphLayout layout = GlyphLayout();

  double _elapsed = 0;
  // Track which cell the mouse is over (for hover highlight)
  int _hoveredIndex = -1;

  WaitingRoomScreen(this.game);

  @override
  void render(double delta) {
    _elapsed += delta;
    final AppData appData = game.getAppData();

    if (appData.phase == MatchPhase.playing || appData.phase == MatchPhase.finished) {
      game.setScreen(PlayScreen(game));
      return;
    }

    ScreenUtils.clear(background);
    viewport.apply();

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    // ── Background panels ──────────────────────────────────────────────────
    shapes.begin(ShapeType.filled);
    shapes.setColor(const ui.Color(0xFF0D1117));
    shapes.rect(0, 0, worldWidth - panelWidth, worldHeight);
    shapes.end();

    shapes.begin(ShapeType.filled);
    shapes.setColor(panelFill);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(panelStroke);
    shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
    shapes.end();

    // ── Pokémon selection grid ─────────────────────────────────────────────
    _renderPokemonGrid(shapes, appData);

    // ── Text ──────────────────────────────────────────────────────────────
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();

    // Title
    font.getData().setScale(3.2);
    font.setColor(titleColor);
    layout.setText(font, 'Pokémon Battle Royale');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.92);

    // Choose your Pokémon
    font.getData().setScale(1.5);
    font.setColor(highlightColor);
    layout.setText(font, 'Tria el teu Pokémon:');
    font.draw(batch, layout, gridStartX, worldHeight * 0.62);

    // Countdown label
    font.getData().setScale(1.4);
    font.setColor(dimTextColor);
    layout.setText(font, 'La partida comença en');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.18);

    // Countdown number
    font.getData().setScale(5.5);
    font.setColor(highlightColor);
    final String countdown = '${math.max(0, appData.countdownSeconds)}';
    layout.setText(font, countdown);
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.12);

    // Controls reminder
    font.getData().setScale(1.1);
    font.setColor(textColor);
    layout.setText(font, 'WASD = Moure    ESPAI = Atacar');
    font.draw(batch, layout, (worldWidth - panelWidth - layout.width) / 2, worldHeight * 0.04);

    // Right panel — player list
    font.getData().setScale(1.3);
    font.setColor(titleColor);
    font.drawText('Jugadors', worldWidth - panelWidth + panelPadding, 30);

    font.getData().setScale(0.85);
    font.setColor(dimTextColor);
    font.drawText('Esperant la partida...', worldWidth - panelWidth + panelPadding, 52);

    double rowY = 84;
    for (final MultiplayerPlayer player in appData.sortedPlayers) {
      final bool isLocal = player.id == appData.playerId;
      final ui.Color nameColor = isLocal ? localPlayerColor : textColor;
      font.getData().setScale(0.95);
      font.setColor(nameColor);
      final String displayName = player.name.length > 12 ? player.name.substring(0, 12) : player.name;
      font.drawText(
        '${isLocal ? "▶ " : "  "}$displayName',
        worldWidth - panelWidth + panelPadding,
        rowY,
      );
      // Show their pokemon name
      font.getData().setScale(0.72);
      font.setColor(dimTextColor);
      font.drawText(
        '   ${_pokemonDisplayName(player.pokemonId)}',
        worldWidth - panelWidth + panelPadding,
        rowY + 16,
      );
      font.getData().setScale(0.95);
      rowY += 42;
      if (rowY > worldHeight - 20) break;
    }

    if (appData.sortedPlayers.isEmpty) {
      font.getData().setScale(0.9);
      font.setColor(dimTextColor);
      font.drawText('Connectant...', worldWidth - panelWidth + panelPadding, 84);
    }

    font.getData().setScale(1);
    batch.end();

    // ── Pokemon name labels on grid (drawn after batch) ────────────────────
    _renderPokemonLabels(batch, font, appData);
  }

  void _renderPokemonGrid(ShapeRenderer shapes, AppData appData) {
    final String localPokemon = appData.localPlayer?.pokemonId ?? '';
    final List<PokemonInfo> pokeList = appData.pokemonList;
    if (pokeList.isEmpty) return;

    // Which pokemon are taken by other players
    final Set<String> takenPokemon = {};
    for (final MultiplayerPlayer p in appData.players) {
      if (p.id != appData.playerId) takenPokemon.add(p.pokemonId);
    }

    for (int i = 0; i < pokeList.length; i++) {
      final PokemonInfo poke = pokeList[i];
      final int col = i % gridCols;
      final int row = i ~/ gridCols;

      // Convert grid coords to world coords (Y flipped: 0 = bottom in libgdx)
      final double x = gridStartX + col * (cellSize + cellPad);
      // In libgdx viewport y=0 is bottom, so we place rows downward from top
      final double y = worldHeight * 0.58 - row * (cellSize + cellPad);

      final ui.Color pokeColor = _parseColor(poke.color);
      final bool isSelected   = poke.id == localPokemon;
      final bool isTaken      = takenPokemon.contains(poke.id);
      final bool isHovered    = i == _hoveredIndex;

      // Shadow
      shapes.begin(ShapeType.filled);
      shapes.setColor(const ui.Color(0x44000000));
      shapes.rect(x + 4, y - 4, cellSize, cellSize);
      shapes.end();

      // Cell background (darker if taken by someone else)
      shapes.begin(ShapeType.filled);
      shapes.setColor(isTaken && !isSelected
          ? const ui.Color(0xFF111622)
          : pokeColor.withAlpha(isSelected ? 80 : 40));
      shapes.rect(x, y, cellSize, cellSize);
      shapes.end();

      // Pokémon icon placeholder: big colored circle
      shapes.begin(ShapeType.filled);
      shapes.setColor(isTaken && !isSelected ? pokeColor.withAlpha(60) : pokeColor);
      shapes.circle(x + cellSize / 2, y + cellSize / 2 + 10, 22, 16);
      shapes.end();

      // Element indicator dot (bottom-right)
      shapes.begin(ShapeType.filled);
      shapes.setColor(_elementColor(poke.element));
      shapes.circle(x + cellSize - 10, y + 10, 6, 8);
      shapes.end();

      // Border
      shapes.begin(ShapeType.line);
      if (isSelected) {
        shapes.setColor(selectedBorder);
      } else if (isHovered) {
        shapes.setColor(hoverBorder);
      } else {
        shapes.setColor(const ui.Color(0xFF2A3050));
      }
      shapes.rect(x, y, cellSize, cellSize);
      shapes.end();

      // Selected checkmark
      if (isSelected) {
        shapes.begin(ShapeType.line);
        shapes.setColor(selectedBorder);
        shapes.rect(x + 2, y + 2, cellSize - 4, cellSize - 4);
        shapes.end();
      }
    }
  }

  void _renderPokemonLabels(SpriteBatch batch, BitmapFont font, AppData appData) {
    final List<PokemonInfo> pokeList = appData.pokemonList;
    if (pokeList.isEmpty) return;

    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();
    for (int i = 0; i < pokeList.length; i++) {
      final PokemonInfo poke = pokeList[i];
      final int col = i % gridCols;
      final int row = i ~/ gridCols;
      final double x = gridStartX + col * (cellSize + cellPad);
      final double y = worldHeight * 0.58 - row * (cellSize + cellPad);

      font.getData().setScale(0.65);
      font.setColor(textColor);
      font.drawText(poke.name, x + 4, y + 18);
    }
    font.getData().setScale(1);
    batch.end();
  }

  @override
  void handleInput() {
    // Handle mouse click on pokemon grid
    final AppData appData = game.getAppData();
    if (appData.phase != MatchPhase.waiting) return;
    final List<PokemonInfo> pokeList = appData.pokemonList;
    if (pokeList.isEmpty) return;

    // We use Gdx.input but need to convert screen → world coords
    // (libgdx_compat click handling happens via justTouched)
    if (Gdx.input.justTouched()) {
      final double mx = viewport.unprojectX(Gdx.input.getX().toDouble());
      final double my = viewport.unprojectY(Gdx.input.getY().toDouble());

      for (int i = 0; i < pokeList.length; i++) {
        final int col = i % gridCols;
        final int row = i ~/ gridCols;
        final double x = gridStartX + col * (cellSize + cellPad);
        final double y = worldHeight * 0.58 - row * (cellSize + cellPad);

        if (mx >= x && mx <= x + cellSize && my >= y && my <= y + cellSize) {
          appData.sendPokemonSelection(pokeList[i].id);
          break;
        }
      }
    }
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _pokemonDisplayName(String pokemonId) {
    // Simple capitalize-first-letter since we don't have full catalogue client-side
    if (pokemonId.isEmpty) return '???';
    return pokemonId[0].toUpperCase() + pokemonId.substring(1);
  }

  ui.Color _parseColor(String hex) {
    try {
      final String h = hex.replaceAll('#', '');
      if (h.length == 6) return ui.Color(0xFF000000 | int.parse(h, radix: 16));
    } catch (_) {}
    return const ui.Color(0xFFAAAAAA);
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
}
