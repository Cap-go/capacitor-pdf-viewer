#!/usr/bin/env bun
/**
 * Sample the top-left margin of a Maestro screenshot and require a near match to RGB.
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

const sampleX = Math.min(24, png.width - 1);
const sampleY = Math.min(Math.floor(png.height * 0.45), png.height - 1);
const idx = (png.width * sampleY + sampleX) * 4;
const r = png.data[idx];
const g = png.data[idx + 1];
const b = png.data[idx + 2];

const within = (a, b) => Math.abs(a - b) <= tolerance;
if (!within(r, wantR) || !within(g, wantG) || !within(b, wantB)) {
  console.error(
    `Pixel (${sampleX},${sampleY}) got rgb(${r},${g},${b}) expected ~(${wantR},${wantG},${wantB}) tol ${tolerance}`,
  );
  process.exit(1);
}

console.log(`Pixel check ok at (${sampleX},${sampleY}) rgb(${r},${g},${b})`);