import { afterEach, describe, expect, it } from 'bun:test';

import { PdfViewerWeb } from './web';

const MINIMAL_PDF_BASE64 =
  'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmoKMiAwIG9iago8PC9UeXBlL1BhZ2VzL0tpZHMgWzMgMCBSXS9Db3VudCAxPj4KZW5kb2JqCjMgMCBvYmoKPDwvVHlwZS9QYWdlL01lZGlhQm94IFswIDAgNjEyIDc5Ml0+PgplbmRvYmoKc3RyZWFtCmVuZG9iago0IDAgb2JqCjw8L1NpemUgND4+CnRyYWlsZXIKPDwvUm9vdCAxIDAgUj4+CnN0YXJ0eHJlZgoxOTQKJSVFT0YK';

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
    await expect(viewer.open({ source: MINIMAL_PDF_BASE64, sourceType: 'base64', mode: 'inline' })).rejects.toThrow(
      'elementId is required when mode is inline',
    );
  });

  it('opens fullscreen base64 PDFs and closes cleanly', async () => {
    const result = await viewer.open({
      source: MINIMAL_PDF_BASE64,
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
      source: MINIMAL_PDF_BASE64,
      sourceType: 'base64',
      mode: 'fullscreen',
      page: 1,
    });
    await viewer.goToPage({ page: 2 });
    const frame = document.querySelector('iframe[title="PDF Viewer"]') as HTMLIFrameElement;
    expect(frame.src).toContain('#page=2');
  });

  it('resolves setZoom without throwing on web', async () => {
    await viewer.open({
      source: MINIMAL_PDF_BASE64,
      sourceType: 'base64',
      mode: 'fullscreen',
    });
    await expect(viewer.setZoom({ scale: 1.5 })).resolves.toBeUndefined();
  });
});
