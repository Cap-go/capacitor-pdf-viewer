import type { PluginListenerHandle } from '@capacitor/core';

/**
 * How the `source` string should be interpreted.
 * When omitted, the plugin infers the type from the string shape.
 *
 * @since 8.0.0
 */
export type PdfSourceType = 'file' | 'path' | 'url' | 'base64';

/**
 * Presentation mode for the viewer.
 *
 * - `fullscreen`: covers the app with a native or browser overlay.
 * - `inline`: places the viewer over a DOM element identified by `elementId`.
 *
 * @since 8.0.0
 */
export type PdfDisplayMode = 'fullscreen' | 'inline';

/**
 * Page scrolling behavior.
 *
 * - `continuous`: pages flow vertically as one scrollable document.
 * - `single`: one page at a time.
 *
 * @since 8.0.0
 */
export type PdfScrollMode = 'continuous' | 'single';

/**
 * Options for {@link PdfViewerPlugin.open}.
 *
 * @since 8.0.0
 */
export interface OpenPdfOptions {
  /**
   * PDF location: file URL, device path, https URL, or base64 (raw or `data:` URI).
   *
   * @example "https://example.com/invoice.pdf"
   * @example "/var/mobile/Containers/Data/invoice.pdf"
   */
  source: string;
  /**
   * Explicit source kind. When omitted:
   * - `data:` or raw base64 without a scheme => `base64`
   * - `http`/`https` => `url`
   * - otherwise => `file` (treated like a path or file URL; `path` is an alias on native)
   *
   * @since 8.0.0
   */
  sourceType?: PdfSourceType;
  /**
   * HTTP headers used when downloading an https `url` source (for example auth tokens).
   *
   * @since 8.0.0
   */
  headers?: Record<string, string>;
  /**
   * Password for encrypted PDFs on iOS and Android.
   * On web the password cannot be injected into the browser viewer; the browser may still prompt.
   *
   * @since 8.0.0
   */
  password?: string;
  /**
   * How to present the viewer.
   *
   * @default 'fullscreen'
   * @since 8.0.0
   */
  mode?: PdfDisplayMode;
  /**
   * DOM element id used when `mode` is `inline`.
   * Native code measures this element and places the viewer over it.
   *
   * @since 8.0.0
   */
  elementId?: string;
  /**
   * Initial page, 1-based.
   *
   * @since 8.0.0
   */
  page?: number;
  /**
   * Scroll behavior inside the viewer.
   *
   * @default 'continuous'
   * @since 8.0.0
   */
  scrollMode?: PdfScrollMode;
}

/**
 * Result returned after a PDF successfully opens.
 *
 * @since 8.0.0
 */
export interface OpenPdfResult {
  /**
   * Total number of pages in the document.
   */
  pageCount: number;
  /**
   * Current page, 1-based.
   */
  page: number;
}

/**
 * Options for {@link PdfViewerPlugin.goToPage}.
 *
 * @since 8.0.0
 */
export interface GoToPageOptions {
  /**
   * Target page, 1-based.
   */
  page: number;
}

/**
 * Options for {@link PdfViewerPlugin.setZoom}.
 *
 * @since 8.0.0
 */
export interface SetZoomOptions {
  /**
   * Zoom multiplier. `1` is the default fit scale on native.
   */
  scale: number;
}

/**
 * Plugin version payload from {@link PdfViewerPlugin.getPluginVersion}.
 *
 * @since 8.0.0
 */
export interface PluginVersionResult {
  /**
   * Version identifier returned by the platform implementation (`native` on iOS/Android, `web` on web).
   */
  version: string;
}

/**
 * Payload for the `load` event.
 *
 * @since 8.0.0
 */
export interface PdfLoadEvent {
  /**
   * Total number of pages.
   */
  pageCount: number;
  /**
   * Current page, 1-based.
   */
  page: number;
}

/**
 * Payload for the `pageChange` event.
 *
 * @since 8.0.0
 */
export interface PdfPageChangeEvent {
  /**
   * Current page, 1-based.
   */
  page: number;
  /**
   * Total number of pages.
   */
  pageCount: number;
}

/**
 * Payload for the `error` event.
 *
 * @since 8.0.0
 */
export interface PdfErrorEvent {
  /**
   * Human-readable error message.
   */
  message: string;
}

/**
 * Payload for the `close` event (empty object).
 *
 * @since 8.0.0
 */
export type PdfCloseEvent = Record<string, never>;

/**
 * Payload for the `linkTap` event.
 *
 * @since 8.0.0
 */
export interface PdfLinkTapEvent {
  /**
   * Destination URL of the tapped link.
   */
  url: string;
}

/**
 * Native PDF viewer for Capacitor (PDFKit on iOS, Pdfium on Android, browser viewer on web).
 *
 * @since 8.0.0
 */
export interface PdfViewerPlugin {
  /**
   * Open a PDF from a file, path, URL, or base64 source.
   *
   * @since 8.0.0
   * @example
   * ```typescript
   * const result = await PdfViewer.open({
   *   source: 'https://example.com/manual.pdf',
   *   headers: { Authorization: 'Bearer token' },
   *   mode: 'fullscreen',
   * });
   * ```
   */
  open(options: OpenPdfOptions): Promise<OpenPdfResult>;

  /**
   * Close the active viewer and remove any overlay.
   *
   * @since 8.0.0
   */
  close(): Promise<void>;

  /**
   * Jump to a 1-based page number in the open document.
   *
   * @since 8.0.0
   */
  goToPage(options: GoToPageOptions): Promise<void>;

  /**
   * Set the zoom scale multiplier (`1` is the default fit scale on native).
   * On web this resolves without changing the browser viewer zoom.
   *
   * @since 8.0.0
   */
  setZoom(options: SetZoomOptions): Promise<void>;

  /**
   * Get the native or web implementation version marker.
   *
   * @since 8.0.0
   */
  getPluginVersion(): Promise<PluginVersionResult>;

  /**
   * Listen for successful PDF load.
   *
   * @since 8.0.0
   */
  addListener(eventName: 'load', listenerFunc: (event: PdfLoadEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for page changes while the user scrolls or when {@link PdfViewerPlugin.goToPage} runs.
   *
   * @since 8.0.0
   */
  addListener(
    eventName: 'pageChange',
    listenerFunc: (event: PdfPageChangeEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for errors while opening or displaying a PDF.
   *
   * @since 8.0.0
   */
  addListener(eventName: 'error', listenerFunc: (event: PdfErrorEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for viewer close (user gesture or {@link PdfViewerPlugin.close}).
   *
   * @since 8.0.0
   */
  addListener(eventName: 'close', listenerFunc: (event: PdfCloseEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for taps on links inside the PDF.
   *
   * @since 8.0.0
   */
  addListener(eventName: 'linkTap', listenerFunc: (event: PdfLinkTapEvent) => void): Promise<PluginListenerHandle>;
}
