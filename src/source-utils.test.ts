import { describe, expect, it } from 'bun:test';

import { inferSourceType, looksLikeBase64 } from './source-utils';

describe('inferSourceType', () => {
  it('detects https URLs', () => {
    expect(inferSourceType('https://example.com/doc.pdf')).toBe('url');
  });

  it('detects data URIs as base64', () => {
    expect(inferSourceType('data:application/pdf;base64,AAA')).toBe('base64');
  });

  it('detects long raw base64 payloads', () => {
    const payload = 'A'.repeat(40);
    expect(inferSourceType(payload)).toBe('base64');
  });

  it('treats filesystem paths as file', () => {
    expect(inferSourceType('/tmp/doc.pdf')).toBe('file');
  });
});

describe('looksLikeBase64', () => {
  it('rejects short strings', () => {
    expect(looksLikeBase64('abc')).toBe(false);
  });

  it('accepts long base64 alphabet strings', () => {
    expect(looksLikeBase64('A'.repeat(40))).toBe(true);
  });
});
