import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Small valid PDF used by unit tests. */
export const SAMPLE_PDF_BASE64 = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), 'test-fixtures/minimal.pdf'),
).toString('base64');
