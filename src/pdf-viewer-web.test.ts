import { afterEach, describe, expect, it } from 'bun:test';

import { mockFetch } from './test-fetch';
import { SAMPLE_PDF_BASE64 } from './test-fixtures';
import { PdfViewerWeb } from './web';

describe('PdfViewerWeb', () => {
  const viewer = new PdfViewerWeb();

  afterEach(async () => {
    await viewer.close();
    document.body.replaceChildren();
  });

  it('returns the web implementation marker', async () => {
    await expect(viewer.getPluginVersion()).resolves.toEqual({ version: 'web' });
  });

  it('requires elementId for inline mode', async () => {
    await expect(viewer.open({ source: SAMPLE_PDF_BASE64, sourceType: 'base64', mode: 'inline' })).rejects.toThrow(
      'elementId is required when mode is inline',
    );
  });

  it('rejects underWebView on web', async () => {
    await expect(
      viewer.open({ source: SAMPLE_PDF_BASE64, sourceType: 'base64', mode: 'underWebView' }),
    ).rejects.toThrow(/not available on web/i);
  });

  it('rejects toBack on web', async () => {
    await expect(viewer.open({ source: SAMPLE_PDF_BASE64, sourceType: 'base64', toBack: true })).rejects.toThrow(
      /not available on web/i,
    );
  });

  it('opens url sources with forwarded headers', async () => {
    const pdfBytes = Uint8Array.from(atob(SAMPLE_PDF_BASE64), (char) => char.charCodeAt(0));
    const originalFetch = globalThis.fetch;
    let seenHeaders: HeadersInit | undefined;
    globalThis.fetch = mockFetch(async (_input, init) => {
      seenHeaders = init?.headers;
      return new Response(pdfBytes, { status: 200, headers: { 'Content-Type': 'application/pdf' } });
    });
    try {
      await viewer.open({
        source: 'https://example.com/doc.pdf',
        sourceType: 'url',
        headers: { Authorization: 'Bearer test' },
        mode: 'fullscreen',
      });
      expect(seenHeaders).toEqual({ Authorization: 'Bearer test' });
      expect(document.querySelector('iframe[title="PDF Viewer"]')).not.toBeNull();
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('rejects failed url downloads', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = mockFetch(async () => new Response('', { status: 404 }));
    try {
      await expect(
        viewer.open({ source: 'https://example.com/missing.pdf', sourceType: 'url', mode: 'fullscreen' }),
      ).rejects.toThrow('Failed to download PDF (404)');
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('revokes blob urls after closing url sources', async () => {
    const revoked: string[] = [];
    const originalCreate = URL.createObjectURL.bind(URL);
    const originalRevoke = URL.revokeObjectURL.bind(URL);
    const originalFetch = globalThis.fetch;
    URL.createObjectURL = () => 'blob:test-revoke';
    URL.revokeObjectURL = (url) => {
      revoked.push(url);
      originalRevoke(url);
    };
    globalThis.fetch = mockFetch(async () => new Response(new Uint8Array([1, 2, 3]), { status: 200 }));
    try {
      await viewer.open({
        source: 'https://example.com/a.pdf',
        sourceType: 'url',
        mode: 'fullscreen',
      });
      await viewer.close();
      expect(revoked).toContain('blob:test-revoke');
    } finally {
      globalThis.fetch = originalFetch;
      URL.createObjectURL = originalCreate;
      URL.revokeObjectURL = originalRevoke;
    }
  });

  it('opens fullscreen base64 PDFs and closes cleanly', async () => {
    const result = await viewer.open({
      source: SAMPLE_PDF_BASE64,
      sourceType: 'base64',
      mode: 'fullscreen',
    });
    expect(result.page).toBe(1);
    expect(result.pageCount).toBeGreaterThanOrEqual(1);
    expect(document.querySelector('iframe[title="PDF Viewer"]')).not.toBeNull();
    await viewer.close();
    expect(document.querySelector('iframe[title="PDF Viewer"]')).toBeNull();
  });

  it('rejects goToPage when no document is open', async () => {
    await expect(viewer.goToPage({ page: 1 })).rejects.toThrow('No PDF is open');
  });

  it('updates iframe hash on goToPage', async () => {
    await viewer.open({
      source: SAMPLE_PDF_BASE64,
      sourceType: 'base64',
      mode: 'fullscreen',
      page: 1,
    });
    await viewer.goToPage({ page: 2 });
    const frame = document.querySelector('iframe[title="PDF Viewer"]') as HTMLIFrameElement;
    expect(frame.src).toContain('#page=2');
  });

  it('does not emit error when a superseded url download fails', async () => {
    const racingViewer = new PdfViewerWeb();
    const errorEvents: { message: string }[] = [];
    await racingViewer.addListener('error', (event) => {
      errorEvents.push(event);
    });
    const originalFetch = globalThis.fetch;
    let rejectSlow: ((reason?: unknown) => void) | undefined;
    globalThis.fetch = mockFetch((input) => {
      if (String(input).includes('slow.pdf')) {
        return new Promise<Response>((_resolve, reject) => {
          rejectSlow = reject;
        });
      }
      return Promise.resolve(new Response(new Uint8Array([1, 2, 3]), { status: 200 }));
    });
    try {
      const slow = racingViewer.open({
        source: 'https://example.com/slow.pdf',
        sourceType: 'url',
        mode: 'fullscreen',
      });
      await racingViewer.open({
        source: SAMPLE_PDF_BASE64,
        sourceType: 'base64',
        mode: 'fullscreen',
      });
      rejectSlow?.(new Error('Failed to download PDF (503)'));
      await expect(slow).rejects.toThrow('PDF open was superseded');
      expect(errorEvents).toHaveLength(0);
      await racingViewer.close();
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('resolves setZoom without throwing on web', async () => {
    await viewer.open({
      source: SAMPLE_PDF_BASE64,
      sourceType: 'base64',
      mode: 'fullscreen',
    });
    await expect(viewer.setZoom({ scale: 1.5 })).resolves.toBeUndefined();
  });
});
