import 'dart:ui' as ui;

import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'waiting_room_screen.dart';

/// Simple loading screen for BattleRoyale — no Games-Tool assets needed.
/// Shows a brief animated bar, then transitions to WaitingRoomScreen.
class LoadingScreen extends ScreenAdapter {
  static const double worldWidth = 1280;
  static const double worldHeight = 720;
  static const double minSecondsOnScreen = 0.6;

  static final ui.Color background = colorValueOf('050A12');
  static final ui.Color barBg = colorValueOf('0D1117');
  static final ui.Color barFill = colorValueOf('58A6FF');
  static final ui.Color textColor = colorValueOf('58A6FF');
  static final ui.Color subtextColor = colorValueOf('3A6FA8');

  final GameApp game;
  final Viewport viewport = FitViewport(
    worldWidth,
    worldHeight,
    OrthographicCamera(),
  );
  final GlyphLayout layout = GlyphLayout();

  double _elapsedSeconds = 0;

  LoadingScreen(this.game);

  @override
  void render(double delta) {
    _elapsedSeconds += delta;

    // Transition to waiting room after minimum display time
    if (_elapsedSeconds >= minSecondsOnScreen) {
      game.setScreen(WaitingRoomScreen(game));
      return;
    }

    final double progress = (_elapsedSeconds / minSecondsOnScreen).clamp(0.0, 1.0);

    ScreenUtils.clear(background);
    viewport.apply();

    _renderBar(progress);
    _renderText(progress);
  }

  void _renderBar(double progress) {
    const double barWidth = 500;
    const double barHeight = 24;
    final double x = (worldWidth - barWidth) * 0.5;
    final double y = worldHeight * 0.46;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.setProjectionMatrix(viewport.getCamera().combined);

    shapes.begin(ShapeType.filled);
    shapes.setColor(barBg);
    shapes.rect(x, y, barWidth, barHeight);
    // Animated fill
    shapes.setColor(barFill);
    shapes.rect(x, y, barWidth * progress, barHeight);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(barFill);
    shapes.rect(x, y, barWidth, barHeight);
    shapes.end();
  }

  void _renderText(double progress) {
    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.setProjectionMatrix(viewport.getCamera().combined);
    batch.begin();

    font.getData().setScale(2.2);
    font.setColor(textColor);
    layout.setText(font, 'BattleRoyale');
    font.draw(batch, layout, (worldWidth - layout.width) / 2, worldHeight * 0.38);

    font.getData().setScale(1.1);
    font.setColor(subtextColor);
    layout.setText(font, 'Connecting to server...');
    font.draw(batch, layout, (worldWidth - layout.width) / 2, worldHeight * 0.58);

    font.getData().setScale(1);
    batch.end();
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), true);
  }
}
