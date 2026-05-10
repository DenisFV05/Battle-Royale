import 'app_data.dart';
import 'level_loader.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'loading_screen.dart';
import 'network_config.dart';
import 'pokemon_sprites.dart';

/// Core game application for BattleRoyale.
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
    // Load all Pokémon sprites from assets
    await PokemonSpriteRegistry.instance.loadAll();
    
    // Load level data
    await LevelLoader.initialize();
    appData.levelData = LevelLoader.loadLevel(0);
    
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

  /// Queues textures for the tilemap layers.
  void queueReferencedAssetsForLevel(int levelIndex) {
    final levelData = appData.levelData;
    if (levelData != null) {
      for (final layer in levelData.layers.iterable()) {
        if (layer.visible && layer.tilesTexturePath.isNotEmpty) {
          assetManager.load(layer.tilesTexturePath, Texture);
        }
      }
    }
  }

  @override
  void dispose() {
    appData.dispose();
    assetManager.dispose();
    _font?.dispose();
    _shapeRenderer?.dispose();
    super.dispose();
  }
}
