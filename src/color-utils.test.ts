import { describe, expect, it } from 'bun:test';

import { parseCssHexColor } from './color-utils';

describe('parseCssHexColor', () => {
  it('accepts #RRGGBB', () => {
    expect(parseCssHexColor('#1a2b3c')).toBe('#1a2b3c');
  });

  it('accepts #AARRGGBB', () => {
    expect(parseCssHexColor('#80112233')).toBe('#80112233');
  });

  it('normalizes case', () => {
    expect(parseCssHexColor('#ABCDEF')).toBe('#abcdef');
  });

  it('rejects invalid values', () => {
    expect(parseCssHexColor('nope')).toBeNull();
    expect(parseCssHexColor('#12345')).toBeNull();
    expect(parseCssHexColor('#gggggg')).toBeNull();
    expect(parseCssHexColor(undefined)).toBeNull();
  });
});
