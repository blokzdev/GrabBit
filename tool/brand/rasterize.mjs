// Dev-only: render brand SVGs to preview strips (and, later, PNG masters).
// Usage: cd tool/brand && npm i && node rasterize.mjs
import sharp from 'sharp';
import { readFileSync, mkdirSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const here = dirname(fileURLToPath(import.meta.url));
const assets = resolve(here, '../../assets/brand');
const out = resolve(assets, 'previews');
mkdirSync(out, { recursive: true });

const PANEL = 512;
const MARK = 360;
const OFF = (PANEL - MARK) / 2;
const BRAND = '#5A3FE0';
const LIGHT = { r: 245, g: 244, b: 250, alpha: 1 };
const DARK = { r: 18, g: 16, b: 25, alpha: 1 };
const dirs = ['a', 'b', 'c'];

const renderMark = (svg) =>
  sharp(Buffer.from(svg), { density: 384 })
    .resize(MARK, MARK, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();

const solidPanel = (bg) =>
  sharp({ create: { width: PANEL, height: PANEL, channels: 4, background: bg } }).png().toBuffer();

const iconTile = async () => {
  const round = `<svg xmlns="http://www.w3.org/2000/svg" width="${PANEL}" height="${PANEL}"><rect width="${PANEL}" height="${PANEL}" rx="116" fill="${BRAND}"/></svg>`;
  return sharp(Buffer.from(round)).png().toBuffer();
};

const compose = async (baseBuf, markBuf) =>
  sharp(baseBuf).composite([{ input: markBuf, top: OFF, left: OFF }]).png().toBuffer();

for (const d of dirs) {
  const svg = readFileSync(resolve(assets, `logo_${d}.svg`), 'utf8');
  const colorMark = await renderMark(svg);
  const whiteMark = await renderMark(svg.replace(/#5A3FE0/gi, '#FFFFFF').replace(/#FF8A4C/gi, '#FFFFFF'));

  const light = await compose(await solidPanel(LIGHT), colorMark);
  const dark = await compose(await solidPanel(DARK), colorMark);
  const icon = await compose(await iconTile(), whiteMark);

  // Horizontal strip: [in-app light | in-app dark | launcher icon]
  const strip = await sharp({
    create: { width: PANEL * 3, height: PANEL, channels: 4, background: { r: 255, g: 255, b: 255, alpha: 1 } },
  })
    .composite([
      { input: light, left: 0, top: 0 },
      { input: dark, left: PANEL, top: 0 },
      { input: icon, left: PANEL * 2, top: 0 },
    ])
    .png()
    .toBuffer();

  const file = resolve(out, `direction_${d}.png`);
  await sharp(strip).toFile(file);
  console.log('wrote', file);
}
