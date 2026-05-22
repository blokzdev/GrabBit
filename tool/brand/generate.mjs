// Dev-only: render the finalized GrabBit mark (Direction B) into PNG masters that
// feed flutter_launcher_icons + flutter_native_splash, plus a confirmation preview.
// Usage: cd tool/brand && npm i && node generate.mjs
import sharp from 'sharp';
import { readFileSync, mkdirSync } from 'fs';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';

const here = dirname(fileURLToPath(import.meta.url));
const assets = resolve(here, '../../assets/brand');
const gen = resolve(assets, 'generated');
const previews = resolve(assets, 'previews');
mkdirSync(gen, { recursive: true });
mkdirSync(previews, { recursive: true });

const BRAND = '#5A3FE0';
const logo = readFileSync(resolve(assets, 'logo.svg'), 'utf8');
const mono = readFileSync(resolve(assets, 'logo_mono.svg'), 'utf8');

// Color variants derived from the two source SVGs.
const whiteBunny = logo.replace(/#5A3FE0/gi, '#FFFFFF'); // white ears+head, amber chevron
const whiteHollow = mono.replace(/#5A3FE0/gi, '#FFFFFF'); // white silhouette, chevron hole
const darkHollow = mono.replace(/#5A3FE0/gi, '#3A2A8C'); // for themed-icon preview

// Tight square viewBox around the mark's bounds (ears+head), so adaptive masters
// fill the safe zone after flutter_launcher_icons applies its own 16% inset.
const tight = (svg) => svg.replace('viewBox="0 0 512 512"', 'viewBox="71 62 370 370"');

const render = (svg, px) =>
  sharp(Buffer.from(svg), { density: 512 })
    .resize(px, px, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();

const canvas = (size, bg) =>
  sharp({ create: { width: size, height: size, channels: 4, background: bg } });

const TRANSPARENT = { r: 0, g: 0, b: 0, alpha: 0 };
const centered = (markBuf, markPx, size) => {
  const off = Math.round((size - markPx) / 2);
  return { input: markBuf, top: off, left: off };
};

async function master(name, { bg, svg, markPx, size = 1024 }) {
  const mark = await render(svg, markPx);
  const base = canvas(size, bg);
  const buf = await base.composite([centered(mark, markPx, size)]).png().toBuffer();
  const file = resolve(gen, name);
  await sharp(buf).toFile(file);
  console.log('master', name);
}

// --- Launcher icon masters (1024) ---
// Adaptive foreground: tight-cropped mark nearly fills the canvas; the 16% inset
// flutter_launcher_icons adds then lands it in the ~66% safe zone.
await master('icon_foreground.png', { bg: TRANSPARENT, svg: tight(whiteBunny), markPx: 1000 });
// Adaptive monochrome: white silhouette w/ hollow chevron, same framing.
await master('icon_monochrome.png', { bg: TRANSPARENT, svg: tight(whiteHollow), markPx: 1000 });
// Legacy/round square: brand fill + white mark (launcher applies the mask shape).
await master('icon_legacy.png', { bg: BRAND, svg: tight(whiteBunny), markPx: 760 });

// --- Splash master (1024) ---
await master('splash_logo.png', { bg: TRANSPARENT, svg: tight(whiteBunny), markPx: 600 });

// --- Confirmation preview: [in-app light | launcher icon | themed/mono (hollow)] ---
const PANEL = 512;
const MK = 360;
const off = (PANEL - MK) / 2;
const panel = async (bgSvgOrColor, markSvg, isRound = false) => {
  let base;
  if (typeof bgSvgOrColor === 'string' && bgSvgOrColor.startsWith('<svg')) {
    base = await sharp(Buffer.from(bgSvgOrColor)).png().toBuffer();
  } else {
    base = await canvas(PANEL, bgSvgOrColor).png().toBuffer();
  }
  const mark = await render(markSvg, MK);
  return sharp(base).composite([{ input: mark, top: off, left: off }]).png().toBuffer();
};
const roundTile = (color) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${PANEL}" height="${PANEL}"><rect width="${PANEL}" height="${PANEL}" rx="116" fill="${color}"/></svg>`;

const pLight = await panel({ r: 245, g: 244, b: 250, alpha: 1 }, logo);
const pIcon = await panel(roundTile(BRAND), whiteBunny);
const pThemed = await panel(roundTile('#E4DEFB'), darkHollow);

const strip = await sharp({
  create: { width: PANEL * 3, height: PANEL, channels: 4, background: { r: 255, g: 255, b: 255, alpha: 1 } },
})
  .composite([
    { input: pLight, left: 0, top: 0 },
    { input: pIcon, left: PANEL, top: 0 },
    { input: pThemed, left: PANEL * 2, top: 0 },
  ])
  .png()
  .toBuffer();
await sharp(strip).toFile(resolve(previews, 'direction_b_final.png'));
console.log('preview direction_b_final.png');
