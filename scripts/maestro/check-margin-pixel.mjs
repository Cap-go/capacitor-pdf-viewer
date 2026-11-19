#!/usr/bin/env bun
/**
 * Match a Maestro screenshot to an expected RGB.
 * Default: scan the image (skips harness strip). CAPGO_MAESTRO_PIXEL_SPOT=1: single fixed sample (negative checks).
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
const spotOnly = process.env.CAPGO_MAESTRO_PIXEL_SPOT === '1';

const buffer = readFileSync(pngPath);
const png = PNG.sync.read(buffer);

const within = (a, b) => Math.abs(a - b) <= tolerance;

const sampleAt = (x, y) => {
  const idx = (png.width * y + x) * 4;
  return {
    x,
    y,
    r: png.data[idx],
    g: png.data[idx + 1],
    b: png.data[idx + 2],
  };
};

if (spotOnly) {
  const sampleX = Math.min(24, png.width - 1);
  const sampleY = Math.min(Math.floor(png.height * 0.45), png.height - 1);
  const hit = sampleAt(sampleX, sampleY);
  if (!within(hit.r, wantR) || !within(hit.g, wantG) || !within(hit.b, wantB)) {
    console.error(
      `Pixel (${hit.x},${hit.y}) got rgb(${hit.r},${hit.g},${hit.b}) expected ~(${wantR},${wantG},${wantB}) tol ${tolerance}`,
    );
    process.exit(1);
  }
  console.log(`Pixel check ok at (${hit.x},${hit.y}) rgb(${hit.r},${hit.g},${hit.b})`);
  process.exit(0);
}

const harnessSkipY = Math.min(56, png.height - 1);
const step = 4;

let hit = null;

for (let y = harnessSkipY; y < png.height; y += step) {
  for (let x = 0; x < png.width; x += step) {
    const px = sampleAt(x, y);
    if (within(px.r, wantR) && within(px.g, wantG) && within(px.b, wantB)) {
      hit = px;
      break;
    }
  }
  if (hit) {
    break;
  }
}

if (!hit) {
  const fallback = sampleAt(
    Math.min(24, png.width - 1),
    Math.min(Math.floor(png.height * 0.45), png.height - 1),
  );
  console.error(
    `No pixel matched ~rgb(${wantR},${wantG},${wantB}) tol ${tolerance}; sample at (${fallback.x},${fallback.y}) got rgb(${fallback.r},${fallback.g},${fallback.b})`,
  );
  process.exit(1);
}

console.log(`Pixel check ok at (${hit.x},${hit.y}) rgb(${hit.r},${hit.g},${hit.b})`);