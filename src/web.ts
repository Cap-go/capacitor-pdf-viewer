import { WebPlugin } from '@capacitor/core';

import type {
  GoToPageOptions,
  OpenPdfOptions,
  OpenPdfResult,
  PdfCurrentPageResult,
  PdfLayoutOptions,
  PdfPageCountResult,
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
  private openToken = 0;

  private rejectUnderWebView(options: OpenPdfOptions): void {
    if (options.toBack === true || options.mode === 'underWebView') {
      const message =
        'underWebView / toBack is not available on web. Use fullscreen or inline, or test on iOS/Android.';
      this.notifyListeners('error', { message });
      throw this.unavailable(message);
    }
  }

  /**
   * Open a PDF in the browser viewer (fullscreen overlay or inline host element).
   */
  async open(options: OpenPdfOptions): Promise<OpenPdfResult> {
    this.rejectUnderWebView(options);

    const token = ++this.openToken;
    await this.closeInternal(false);

    const sourceType = options.sourceType ?? inferSourceType(options.source);
    const mode = options.mode ?? 'fullscreen';
    const showNativeUi = options.nativeUi ?? mode === 'fullscreen';

    if (mode === 'inline' && !options.elementId) {
      const message = 'elementId is required when mode is inline';
      this.notifyListeners('error', { message });
      throw new Error(message);
    }

    try {
      const { blobUrl, revoke } = await sourceToBlobUrl(options.source, sourceType, options.headers);
      if (token !== this.openToken) {
        revoke();
        throw new Error('PDF open was superseded');
      }
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
        host.appendChild(frame);
      } else {
        host = document.createElement('div');
        Object.assign(host.style, {
          position: 'fixed',
          inset: '0',
          zIndex: '2147483646',
          background: showNativeUi ? 'rgba(0,0,0,0.92)' : 'transparent',
          display: 'flex',
          flexDirection: 'column',
        });
        if (showNativeUi) {
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
        } else {
          host.appendChild(frame);
        }
        document.body.appendChild(host);
      }

      this.host = host;
      this.frame = frame;
      this.pageCount = 1;
      const result = { pageCount: this.pageCount, page: this.page };
      this.notifyListeners('load', result);
      return result;
    } catch (error) {
      if (token !== this.openToken) {
        const superseded = new Error('PDF open was superseded');
        (superseded as Error & { cause?: unknown }).cause = error;
        throw superseded;
      }
      const message = error instanceof Error ? error.message : String(error);
      const code = (error as { code?: string }).code;
      if (code !== 'UNIMPLEMENTED') {
        this.notifyListeners('error', { message });
      }
      throw error;
    }
  }

  async close(): Promise<void> {
    this.openToken += 1;
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

  async nextPage(): Promise<void> {
    await this.goToPage({ page: Math.min(this.pageCount, this.page + 1) });
  }

  async previousPage(): Promise<void> {
    await this.goToPage({ page: Math.max(1, this.page - 1) });
  }

  async setZoom(options: SetZoomOptions): Promise<void> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    void options;
  }

  async getPageCount(): Promise<PdfPageCountResult> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    return { pageCount: this.pageCount };
  }

  async getCurrentPage(): Promise<PdfCurrentPageResult> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    return { page: this.page };
  }

  async hide(): Promise<void> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    const target = this.host?.parentElement === document.body ? this.host : this.frame;
    target.style.visibility = 'hidden';
  }

  async show(): Promise<void> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    const target = this.host?.parentElement === document.body ? this.host : this.frame;
    target.style.visibility = 'visible';
  }

  async updateLayout(options: PdfLayoutOptions): Promise<void> {
    if (!this.frame) {
      throw new Error('No PDF is open');
    }
    void options;
    throw this.unavailable('updateLayout is only supported on iOS and Android for underWebView / toBack mode.');
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
