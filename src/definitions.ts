import type { PluginListenerHandle } from '@capacitor/core';

/**
 * How the `source` string should be interpreted.
 * When omitted, the plugin infers the type from the string shape.
 */
export type PdfSourceType = 'file' | 'path' | 'url' | 'base64';

/**
 * Presentation mode for the viewer.
 * - `fullscreen`: covers the app with a native/browser overlay.
 * - `inline`: places the viewer over a DOM element identified by `elementId`.
 */
export type PdfDisplayMode = 'fullscreen' | 'inline';

/**
 * Page scrolling behavior.
 * - `continuous`: pages flow vertically (or as one scrollable document).
 * - `single`: one page at a time.
 */
export type PdfScrollMode = 'continuous' | 'single';

/**
 * Options for opening a PDF.
 */
export interface OpenPdfOptions {
  /**
   * PDF location: file URL, device path, https URL, or base64 (raw or `data:` URI).
   */
  source: string;
  /**
   * Explicit source kind. When omitted:
   * - `data:` or raw base64 without a scheme => `base64`
   * - `http`/`https` => `url`
   * - otherwise => `file` (treated like a path/file URL)
   */
  sourceType?: PdfSourceType;
  /**
   * HTTP headers used when downloading an https `url` source (e.g. auth cookies).
   */
  headers?: Record<string, string>;
  /**
   * Password for encrypted PDFs.
   * On web, the password cannot be injected into the browser viewer; the browser may still prompt.
   */
  password?: string;
  /**
   * How to present the viewer.
   * @default 'fullscreen'
   */
  mode?: PdfDisplayMode;
  /**
   * DOM element id used when `mode` is `inline`.
   * Native measures this element and places the viewer over it.
   */
  elementId?: string;
  /**
   * Initial page, 1-based.
   */
  page?: number;
  /**
   * Scroll behavior.
   * @default 'continuous'
   */
  scrollMode?: PdfScrollMode;
}

/**
 * Result returned after a PDF successfully opens.
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
 * Options for jumping to a page.
 */
export interface GoToPageOptions {
  /**
   * Target page, 1-based.
   */
  page: number;
}

/**
 * Options for changing zoom.
 */
export interface SetZoomOptions {
  /**
   * Zoom multiplier. `1` is the fit-ish default scale.
   */
  scale: number;
}

/**
 * Plugin version payload.
 */
export interface PluginVersionResult {
  /**
   * Version identifier returned by the platform implementation.
   */
  version: string;
}

/**
 * Emitted when the PDF finishes loading.
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
 * Emitted when the visible page changes.
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
 * Emitted when opening or rendering fails.
 */
export interface PdfErrorEvent {
  /**
   * Human-readable error message.
   */
  message: string;
}

/**
 * Emitted when the viewer is closed.
 */
export type PdfCloseEvent = Record<string, never>;

/**
 * Emitted when the user taps a link inside the PDF.
 */
export interface PdfLinkTapEvent {
  /**
   * Destination URL of the tapped link.
   */
  url: string;
}

/**
 * Capgo PDF Viewer plugin API.
 */
export interface PdfViewerPlugin {
  /**
   * Open a PDF from a file, path, URL, or base64 source.
   */
  open(options: OpenPdfOptions): Promise<OpenPdfResult>;

  /**
   * Close the active viewer and remove any overlay.
   */
  close(): Promise<void>;

  /**
   * Jump to a 1-based page number.
   */
  goToPage(options: GoToPageOptions): Promise<void>;

  /**
   * Set the zoom scale multiplier (`1` ≈ fit default).
   * On web this resolves without changing the browser viewer zoom.
   */
  setZoom(options: SetZoomOptions): Promise<void>;

  /**
   * Get the native/web implementation version marker.
   */
  getPluginVersion(): Promise<PluginVersionResult>;

  /**
   * Listen for successful PDF load.
   */
  addListener(eventName: 'load', listenerFunc: (event: PdfLoadEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for page changes.
   */
  addListener(
    eventName: 'pageChange',
    listenerFunc: (event: PdfPageChangeEvent) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for errors while opening or displaying a PDF.
   */
  addListener(eventName: 'error', listenerFunc: (event: PdfErrorEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for viewer close.
   */
  addListener(eventName: 'close', listenerFunc: (event: PdfCloseEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for taps on links inside the PDF.
   */
  addListener(eventName: 'linkTap', listenerFunc: (event: PdfLinkTapEvent) => void): Promise<PluginListenerHandle>;
}
