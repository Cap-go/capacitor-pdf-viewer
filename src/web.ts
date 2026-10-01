import { WebPlugin } from '@capacitor/core';

import type {
  GoToPageOptions,
  OpenPdfOptions,
  OpenPdfResult,
  PdfViewerPlugin,
  PluginVersionResult,
  SetZoomOptions,
} from './definitions';
import { inferSourceType, sourceToBlobUrl } from './source-utils';

export class PdfViewerWeb extends WebPlugin implements PdfViewerPlugin {
  private host: HTMLElement | null = null;
  private frame: HTMLIFrameElement | null = null;
  private revokeUrl: (() => void) | null = null;
  private page = 1;
  private pageCount = 1;

  async open(options: OpenPdfOptions): Promise<OpenPdfResult> {
    await this.closeInternal(false);

    const sourceType = options.sourceType ?? inferSourceType(options.source);
    const mode = options.mode ?? 'fullscreen';

    if (mode === 'inline' && !options.elementId) {
      const message = 'elementId is required when mode is inline';
      this.notifyListeners('error', { message });
      throw new Error(message);
    }

    try {
      const { blobUrl, revoke } = await sourceToBlobUrl(options.source, sourceType, options.headers);
      this.revokeUrl = revoke;
      this.page = Math.max(1, options.page ?? 1);
      const url = `${blobUrl}#page=${this.page}`;

      const frame = document.createElement('iframe');
      frame.title = 'PDF Viewer';
      frame.src = url;
      frame.setAttribute('type', 'application/pdf');
      Object.assign(frame.style, {
        border: '0',
        width: '100%',
        height: '100%',
        background: '#111',
      });

      let host: HTMLElement;
      if (mode === 'inline' && options.elementId) {
        const target = document.getElementById(options.elementId);
        if (!target) {
          revoke();
          const message = `Element not found: ${options.elementId}`;
          this.notifyListeners('error', { message });
          throw new Error(message);
        }
        target.replaceChildren();
        host = target;
        Object.assign(host.style, { position: host.style.position || 'relative', overflow: 'hidden' });
      } else {
        host = document.createElement('div');
        Object.assign(host.style, {
          position: 'fixed',
          inset: '0',
          zIndex: '2147483646',
          background: 'rgba(0,0,0,0.92)',
          display: 'flex',
          flexDirection: 'column',
        });
        const toolbar = document.createElement('div');
        Object.assign(toolbar.style, {
          display: 'flex',
          justifyContent: 'flex-end',
          padding: '8px',
          gap: '8px',
        });
        const closeBtn = document.createElement('button');
        closeBtn.textContent = 'Close';
        closeBtn.type = 'button';
        closeBtn.onclick = () => {
          void this.close();
        };
        toolbar.appendChild(closeBtn);
        const wrap = document.createElement('div');
        Object.assign(wrap.style, { flex: '1', minHeight: '0' });
        wrap.appendChild(frame);
        host.appendChild(toolbar);
        host.appendChild(wrap);
        document.body.appendChild(host);
      }

      if (mode === 'inline') {
        host.appendChild(frame);
      }

      this.host = host;
      this.frame = frame;
      // Browser PDF viewers do not expose pageCount reliably; treat as at least 1.
      this.pageCount = 1;
      const result = { pageCount: this.pageCount, page: this.page };
      this.notifyListeners('load', result);
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.notifyListeners('error', { message });
      throw error;
    }
  }

  async close(): Promise<void> {
    await this.closeInternal(true);
  }

  async goToPage(options: GoToPageOptions): Promise<void> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    this.page = Math.max(1, options.page);
    const base = this.frame.src.replace(/#.*$/, '');
    this.frame.src = `${base}#page=${this.page}`;
    this.notifyListeners('pageChange', { page: this.page, pageCount: this.pageCount });
  }

  async setZoom(options: SetZoomOptions): Promise<void> {
    void options;
    // Browser PDF viewer owns zoom; resolve successfully.
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return { version: 'web' };
  }

  private async closeInternal(emit: boolean): Promise<void> {
    if (this.frame) {
      this.frame.remove();
      this.frame = null;
    }
    if (this.host) {
      if (this.host.parentElement === document.body) {
        this.host.remove();
      } else {
        this.host.replaceChildren();
      }
      this.host = null;
    }
    if (this.revokeUrl) {
      this.revokeUrl();
      this.revokeUrl = null;
    }
    if (emit) {
      this.notifyListeners('close', {});
    }
  }
}
