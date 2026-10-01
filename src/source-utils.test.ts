import { describe, expect, it } from 'bun:test';

import { inferSourceType, looksLikeBase64, sourceToBlobUrl } from './source-utils';
import { mockFetch } from './test-fetch';
import { SAMPLE_PDF_BASE64 } from './test-fixtures';

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

describe('sourceToBlobUrl', () => {
  it('passes through file paths without revoking', async () => {
    const { blobUrl, revoke } = await sourceToBlobUrl('/docs/sample.pdf', 'file');
    expect(blobUrl).toBe('/docs/sample.pdf');
    expect(revoke()).toBeUndefined();
  });

  it('creates revocable blob urls for base64 payloads', async () => {
    const { blobUrl, revoke } = await sourceToBlobUrl(SAMPLE_PDF_BASE64, 'base64');
    expect(blobUrl.startsWith('blob:')).toBe(true);
    revoke();
  });

  it('parses data URIs for base64 sources', async () => {
    const dataUri = `data:application/pdf;base64,${SAMPLE_PDF_BASE64.slice(0, 64)}`;
    const { blobUrl, revoke } = await sourceToBlobUrl(dataUri, 'base64');
    expect(blobUrl.startsWith('blob:')).toBe(true);
    revoke();
  });

  it('downloads url sources with headers', async () => {
    const originalFetch = globalThis.fetch;
    let seenHeaders: HeadersInit | undefined;
    globalThis.fetch = mockFetch(async (_input, init) => {
      seenHeaders = init?.headers;
      return new Response(new Uint8Array([1, 2, 3]), { status: 200 });
    });
    try {
      const { blobUrl, revoke } = await sourceToBlobUrl('https://example.com/a.pdf', 'url', {
        Authorization: 'Bearer test',
      });
      expect(seenHeaders).toEqual({ Authorization: 'Bearer test' });
      expect(blobUrl.startsWith('blob:')).toBe(true);
      revoke();
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('throws when url download fails', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mockFetch(async () => new Response('', { status: 500 }));
    try {
      await expect(sourceToBlobUrl('https://example.com/missing.pdf', 'url')).rejects.toThrow(
        'Failed to download PDF (500)',
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
