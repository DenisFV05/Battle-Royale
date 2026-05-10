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
    case 'up':    return 4; // N
    case 'down':  return 0; // S
    case 'left':  return 6; // W
    case 'right': return 2; // E
    default:      return 0;
  }
}

/// Infer number of columns using standard PMD frame widths (24, 32, 40, 48).
/// This is much more robust than a simple divisor check.
int _inferCols(int width, int frameH) {
  // Standard PMD frame widths in these asset packs.
  for (int fw in [40, 32, 24, 48, 64]) {
    if (width % fw == 0 && fw <= frameH + 8) {
      return width ~/ fw;
    }
  }

  // Fallback heuristic: largest fw <= frameH that divides width exactly.
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

SheetInfo _makeSheet(ui.Image img) {
  final int fh   = img.height ~/ kNumRows;
  final int cols = _inferCols(img.width, fh);
  final int fw   = img.width ~/ cols;
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

      final SheetInfo idleS  = _makeSheet(await _load('$base/Idle-Anim.png'));
      final SheetInfo walkS  = _makeSheet(await _load('$base/Walk-Anim.png'));
      final SheetInfo hurtS  = _makeSheet(await _load('$base/Hurt-Anim.png'));
      final SheetInfo faintS = _makeSheet(await _load('$base/Faint-Anim.png'));
      final SheetInfo atkS   = _makeSheet(await _load('$base/$atkName.png'));

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
