// Read PNG width/height from header bytes (no deps needed)
const fs = require('fs');
const path = require('path');

function pngSize(file) {
  const buf = fs.readFileSync(file);
  // PNG header: bytes 16-19 = width, 20-23 = height (big-endian)
  const w = buf.readUInt32BE(16);
  const h = buf.readUInt32BE(20);
  return { w, h };
}

const mediaBase = path.join(__dirname, '../../Flutter/assets/levels/media');
const pokemons = ['pikachu', 'axew', 'buizel'];
const anims = ['Idle-Anim', 'Walk-Anim', 'Hurt-Anim', 'Faint-Anim'];

for (const poke of pokemons) {
  console.log(`\n=== ${poke} ===`);
  for (const anim of anims) {
    const f = path.join(mediaBase, poke, `${anim}.png`);
    if (fs.existsSync(f)) {
      const { w, h } = pngSize(f);
      const frameH_if8rows  = h / 8;
      const frameH_if16rows = h / 16;
      const cols_if8  = Math.round(w / frameH_if8rows);
      const cols_if16 = Math.round(w / frameH_if16rows);
      console.log(`  ${anim}: ${w}x${h}  | if 8rows: frameH=${frameH_if8rows} cols=${cols_if8} | if 16rows: frameH=${frameH_if16rows} cols=${cols_if16}`);
    }
  }
}
