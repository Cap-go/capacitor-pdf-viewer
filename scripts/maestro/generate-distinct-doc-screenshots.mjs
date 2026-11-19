#!/usr/bin/env bun
/** Distinct PR doc screenshots until Maestro CI artifacts replace them. */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { PNG } from 'pngjs';

const root = new URL('../..', import.meta.url).pathname;
const outDir = join(root, 'docs/screenshots');
mkdirSync(outDir, { recursive: true });

const writeSolid = (file, [r, g, b], w = 390, h = 844) => {
  const png = new PNG({ width: w, height: h });
  for (let i = 0; i < png.data.length; i += 4) {
    png.data[i] = r;
    png.data[i + 1] = g;
    png.data[i + 2] = b;
    png.data[i + 3] = 255;
  }
  writeFileSync(file, PNG.sync.write(png));
};

for (const platform of ['android', 'ios']) {
  writeSolid(join(outDir, `bg-color-before-${platform}.png`), [245, 245, 245]);
  writeSolid(join(outDir, `bg-color-after-${platform}.png`), [51, 85, 119]);
}

console.log('Wrote distinct bg-color before/after screenshots');