#!/usr/bin/env bun
/**
 * Require a Maestro screenshot to contain a near match to RGB (scans the image; skips the native harness strip).
 * Usage: bun scripts/maestro/check-margin-pixel.mjs <png> <rr> <gg> <bb> [tolerance]
 */
import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';

const [pngPath, rrRaw, ggRaw, bbRaw, toleranceRaw] = process.argv.slice(2);
if (!pngPath || rrRaw == null || ggRaw == null || bbRaw == null) {
  console.error(
    'Usage: bun scripts/maestro/check-margin-pixel.mjs <png> <rr> <gg> <bb> [tolerance]',
  );
  process.exit(2);
}

const wantR = Number(rrRaw);
const wantG = Number(ggRaw);
const wantB = Number(bbRaw);
const tolerance = Number(toleranceRaw ?? 24);

const buffer = readFileSync(pngPath);
const png = PNG.sync.read(buffer);

const within = (a, b) => Math.abs(a - b) <= tolerance;
const harnessSkipY = Math.min(56, png.height - 1);
const step = 4;

let hit = null;

for (let y = harnessSkipY; y < png.height; y += step) {
  for (let x = 0; x < png.width; x += step) {
    const idx = (png.width * y + x) * 4;
    const r = png.data[idx];
    const g = png.data[idx + 1];
    const b = png.data[idx + 2];
    if (within(r, wantR) && within(g, wantG) && within(b, wantB)) {
      hit = { x, y, r, g, b };
      break;
    }
  }
  if (hit) {
    break;
  }
}

if (!hit) {
  const sampleX = Math.min(24, png.width - 1);
  const sampleY = Math.min(Math.floor(png.height * 0.45), png.height - 1);
  const idx = (png.width * sampleY + sampleX) * 4;
  const r = png.data[idx];
  const g = png.data[idx + 1];
  const b = png.data[idx + 2];
  console.error(
    `No pixel matched ~rgb(${wantR},${wantG},${wantB}) tol ${tolerance}; sample at (${sampleX},${sampleY}) got rgb(${r},${g},${b})`,
  );
  process.exit(1);
}

console.log(`Pixel check ok at (${hit.x},${hit.y}) rgb(${hit.r},${hit.g},${hit.b})`);