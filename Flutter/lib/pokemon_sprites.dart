import 'dart:ui' as ui;
import 'package:flutter/services.dart';

// Direction row index (PMD standard order):
// 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE
const int dirS  = 0;
const int dirSW = 1;
const int dirW  = 2;
const int dirNW = 3;
const int dirN  = 4;
const int dirNE = 5;
const int dirE  = 6;
const int dirSE = 7;

const int kNumRows = 8; // always 8 directional rows

/// Maps server facing string to a PMD direction row.
/// This sprite pack uses the SE-first order: 0=S,1=SE,2=E,3=NE,4=N,5=NW,6=W,7=SW
int facingToRow(String facing) {
  switch (facing) {
    case 'up':         return 4; // N
    case 'down':       return 0; // S
    case 'left':       return 6; // W
    case 'right':      return 2; // E
    case 'upLeft':     return 3; // NW
    case 'up_left':    return 3; // NW
    case 'upRight':    return 5; // NE
    case 'up_right':   return 5; // NE
    case 'downLeft':   return 1; // SW
    case 'down_left':  return 1; // SW
    case 'downRight':  return 7; // SE
    case 'down_right': return 7; // SE
    default:           return 0; // Default to South
  }
}

/// Infers the exact number of columns for a spritesheet.
/// Uses a 100% exact mapping of all 50 sprites to completely eliminate heuristic errors.
/// Infers the exact number of columns for a spritesheet.
/// Uses a 100% exact mapping of all 50 sprites to completely eliminate heuristic errors.
int _inferCols(String pokemonId, String animType, int width, int frameH) {
  // In PMD, 'hurt' animations are consistently 2 frames.
  if (animType == 'hurt') return 2;

  // Exact mapping for every other sprite to guarantee pixel perfection
  final Map<String, int> exactCols = {
    // IDLE
    'axew_idle': 4, 'buizel_idle': 9, 'chimchar_idle': 5, 'misdreavus_idle': 8, 'pikachu_idle': 6,
    'riolu_idle': 4, 'rockruff_idle': 7, 'rowlet_idle': 6, 'snorunt_idle': 4, 'trapinch_idle': 4,
    // WALK
    'axew_walk': 4, 'buizel_walk': 4, 'chimchar_walk': 7, 'misdreavus_walk': 8, 'pikachu_walk': 4,
    'riolu_walk': 4, 'rockruff_walk': 7, 'rowlet_walk': 4, 'snorunt_walk': 4, 'trapinch_walk': 4,
    // FAINT
    'axew_faint': 4, 'buizel_faint': 4, 'chimchar_faint': 4, 'misdreavus_faint': 4, 'pikachu_faint': 4,
    'riolu_faint': 4, 'rockruff_faint': 4, 'rowlet_faint': 4, 'snorunt_faint': 4, 'trapinch_faint': 4,
    // ATTACK
    'axew_attack': 8, 'buizel_attack': 13, 'chimchar_attack': 8, 'misdreavus_attack': 13, 'pikachu_attack': 13,
    'riolu_attack': 6, 'rockruff_attack': 10, 'rowlet_attack': 12, 'snorunt_attack': 11, 'trapinch_attack': 13,
  };

  final key = '${pokemonId}_$animType';
  if (exactCols.containsKey(key)) {
    return exactCols[key]!;
  }

  // Absolute fallback (should never be hit unless a new pokemon is added)
  for (int fw = frameH; fw >= 1; fw--) {
    if (width % fw == 0) return width ~/ fw;
  }
  return 1;
}


// ─── Attack animation name per Pokemon ────────────────────────────────────────
const Map<String, String> kAttackAnim = {
  'axew':       'Strike-Anim',
  'buizel':     'QuickStrike-Anim',
  'chimchar':   'Shoot-Anim',
  'misdreavus': 'Shoot-Anim',
  'pikachu':    'Shock-Anim',
  'riolu':      'RearUp-Anim',
  'rockruff':   'Shoot-Anim',
  'rowlet':     'Shoot-Anim',
  'snorunt':    'Shoot-Anim',
  'trapinch':   'Bite-Anim',
};

// ─── Asset folder name per Pokemon ────────────────────────────────────────────
const Map<String, String> kPokemonFolder = {
  'axew':       'axew',
  'buizel':     'buizel',
  'chimchar':   'chimchar',
  'misdreavus': 'misdreavous',
  'pikachu':    'pikachu',
  'riolu':      'riolu',
  'rockruff':   'rockruff',
  'rowlet':     'rowlet',
  'snorunt':    'snorunt',
  'trapinch':   'trapinch',
};

// ─── Per-sheet frame info ─────────────────────────────────────────────────────
class SheetInfo {
  final ui.Image image;
  final int frameW;
  final int frameH;
  final int cols;
  const SheetInfo({required this.image, required this.frameW, required this.frameH, required this.cols});
}

SheetInfo _makeSheet(String pokemonId, String animType, ui.Image img) {
  final int fh   = img.height ~/ kNumRows;
  final int cols = _inferCols(pokemonId, animType, img.width, fh);
  final int fw   = img.width ~/ cols;
  print('[$pokemonId][$animType] image=${img.width}x${img.height} frame=${fw}x$fh cols=$cols');
  return SheetInfo(image: img, frameW: fw, frameH: fh, cols: cols);
}

// ─── Sprite bundle for one Pokemon ────────────────────────────────────────────
class PokemonSpriteBundle {
  final SheetInfo idle;
  final SheetInfo walk;
  final SheetInfo hurt;
  final SheetInfo faint;
  final SheetInfo attack;

  const PokemonSpriteBundle({
    required this.idle,
    required this.walk,
    required this.hurt,
    required this.faint,
    required this.attack,
  });
}

// ─── Sprite registry ─────────────────────────────────────────────────────────
class PokemonSpriteRegistry {
  static final PokemonSpriteRegistry _instance = PokemonSpriteRegistry._();
  static PokemonSpriteRegistry get instance => _instance;
  PokemonSpriteRegistry._();

  final Map<String, PokemonSpriteBundle> _bundles = {};
  ui.Image? _gem;
  ui.Image? _backBtn;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> loadAll() async {
    if (_loaded) return;
    _gem     = await _load('assets/levels/media/gem.png');
    _backBtn = await _load('assets/other/enrrere.png');

    for (final entry in kPokemonFolder.entries) {
      final String id      = entry.key;
      final String folder  = entry.value;
      final String base    = 'assets/levels/media/$folder';
      final String atkName = kAttackAnim[id] ?? 'Strike-Anim';

      final SheetInfo idleS  = _makeSheet(id, 'idle', await _load('$base/Idle-Anim.png'));
      final SheetInfo walkS  = _makeSheet(id, 'walk', await _load('$base/Walk-Anim.png'));
      final SheetInfo hurtS  = _makeSheet(id, 'hurt', await _load('$base/Hurt-Anim.png'));
      final SheetInfo faintS = _makeSheet(id, 'faint', await _load('$base/Faint-Anim.png'));
      final SheetInfo atkS   = _makeSheet(id, 'attack', await _load('$base/$atkName.png'));

      _bundles[id] = PokemonSpriteBundle(
        idle:   idleS,
        walk:   walkS,
        hurt:   hurtS,
        faint:  faintS,
        attack: atkS,
      );

      // ignore: avoid_print
      print('[$id] idle=${idleS.frameW}x${idleS.frameH}(${idleS.cols}cols) walk=${walkS.frameW}x${walkS.frameH}(${walkS.cols}cols) hurt=${hurtS.frameW}x${hurtS.frameH}(${hurtS.cols}cols)');
    }
    _loaded = true;
  }

  PokemonSpriteBundle? get(String pokemonId) => _bundles[pokemonId];
  ui.Image? get gem     => _gem;
  ui.Image? get backBtn => _backBtn;

  static Future<ui.Image> _load(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }
}

// ─── Sprite Painter helper ────────────────────────────────────────────────────
/// Draw a single frame from a spritesheet onto [canvas].
void drawSpriteFrame({
  required ui.Canvas canvas,
  required SheetInfo sheet,
  required int col,
  required int row,
  required ui.Rect dstRect,
  double alpha = 1.0,
}) {
  final ui.Rect src = ui.Rect.fromLTWH(
    (col * sheet.frameW).toDouble(),
    (row * sheet.frameH).toDouble(),
    sheet.frameW.toDouble(),
    sheet.frameH.toDouble(),
  );
  final ui.Paint paint = ui.Paint()
    ..color = ui.Color.fromARGB((alpha * 255).round(), 255, 255, 255)
    ..filterQuality = ui.FilterQuality.none;
  canvas.drawImageRect(sheet.image, src, dstRect, paint);
}
