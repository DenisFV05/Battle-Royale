import 'app_data.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'loading_screen.dart';
import 'network_config.dart';

/// Core game application for BattleRoyale.
/// Simplified from the professor's Exemple0700 — no Games-Tool level data needed.
/// The world (walls, players, bullets) is sent entirely by the NodeJS server.
class GameApp extends Game {
  final NetworkConfig networkConfig;
  final AppData appData;
  final AssetManager assetManager = AssetManager();

  SpriteBatch? _batch;
  ShapeRenderer? _shapeRenderer;
  BitmapFont? _font;

  GameApp({required this.networkConfig})
      : appData = AppData(initialConfig: networkConfig);

  Future<void> create() async {
    _batch = SpriteBatch();
    _shapeRenderer = ShapeRenderer();
    _font = BitmapFont();
    _font!.getData().markupEnabled = false;
    // No level assets to load — world geometry comes from the server.
    setScreen(LoadingScreen(this));
  }

  SpriteBatch getBatch() => _batch!;
  ShapeRenderer getShapeRenderer() => _shapeRenderer!;
  BitmapFont getFont() => _font!;
  AssetManager getAssetManager() => assetManager;

  AppData getAppData() => appData;

  String getPlayerName() => networkConfig.playerName;
  String getSelectedServerLabel() => networkConfig.serverLabel;

  /// Kept for API compatibility — BattleRoyale has no named levels.
  String getLevelName(int levelIndex) => 'BattleRoyale';

  /// No-op: BattleRoyale uses no pre-loaded texture assets.
  void queueReferencedAssetsForLevel(int levelIndex) {}

  @override
  void dispose() {
    appData.dispose();
    assetManager.dispose();
    _font?.dispose();
    _shapeRenderer?.dispose();
    super.dispose();
  }
}
