# @capgo/capacitor-pdf-viewer

<a href="https://capgo.app/"><img src="https://capgo.app/readme-banner.svg?repo=Cap-go/capacitor-pdf-viewer" alt="Capgo - Instant updates for Capacitor" /></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_pdf_viewer"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_pdf_viewer"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>

**@capgo/capacitor-pdf-viewer** embeds native PDF viewing in Capacitor apps on iOS, Android, and web. Instead of fighting WebView limitations or shipping a heavy JavaScript PDF renderer, you open files from a path, HTTPS URL (with custom headers), or base64 and get system-grade rendering: page navigation, pinch zoom, continuous or single-page scrolling, password-protected documents, fullscreen or inline layout, and events for load, errors, page changes, link taps, and close. On iOS it uses PDFKit; on Android it uses Pdfium; on web it uses the browser PDF viewer with blob URLs.

## Features

- Open PDFs from a device path, `file://` URL, HTTPS URL, or base64 (including `data:` URIs)
- Optional `headers` when downloading remote URLs (auth tokens, cookies)
- Password support for encrypted PDFs on iOS and Android
- Fullscreen overlay or **inline** mode anchored to a DOM element (`elementId`)
- Continuous vertical scrolling or single-page mode
- Programmatic **goToPage**, **setZoom**, and **close**
- Events: `load`, `pageChange`, `error`, `close`, `linkTap`

## Use cases

- Invoices, manuals, and tickets stored on device or returned from your API as base64
- Authenticated document download from a signed URL with custom HTTP headers
- Embedded PDF preview in a form or dashboard region (inline mode)
- Guided reading flows that jump to a page and listen for link taps inside the PDF

<p align="center">
  <img src="./screenshots/android-demo.webp" alt="Android emulator showing the example PDF open on two pages" width="280" />
  <img src="./screenshots/example-app.webp" alt="Example app with inline PDF and controls" width="280" />
</p>

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |
| v7.\*.\*       | v7.\*.\*                | On demand   |
| v6.\*.\*       | v6.\*.\*                | On demand   |

Policy:

- New plugins start at version `8.0.0` (Capacitor 8 baseline).
- Backward compatibility for older Capacitor majors is supported on demand.

## Install

```bash
npm i @capgo/capacitor-pdf-viewer
npx cap sync
```

With Bun:

```bash
bun add @capgo/capacitor-pdf-viewer
bunx cap sync
```

## iOS setup

No extra Info.plist keys or entitlements are required by this plugin. It uses Apple PDFKit. Remote PDFs use `URLSession` with the headers you pass in `open`. For HTTPS URLs, follow your app's usual App Transport Security rules.

## Android setup

The plugin library targets **minSdk 24** (Android 7.0) and bundles Pdfium (`io.legere:pdfiumandroid`). The plugin `AndroidManifest.xml` is empty: it does not declare `INTERNET`, storage, or FileProvider entries. If you open **https** sources, add `INTERNET` to your **app** manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Local files and base64 do not need extra permissions beyond what your app already uses to read those paths.

## Web

No Capacitor sync steps are required for web. URL sources are fetched with your `headers`; `setZoom` is a no-op because zoom is controlled by the browser viewer. Passwords cannot be injected on web; the browser may prompt on its own.

## Usage

```typescript
import { PdfViewer } from '@capgo/capacitor-pdf-viewer';

await PdfViewer.addListener('pageChange', ({ page, pageCount }) => {
  console.log(`Page ${page} of ${pageCount}`);
});

const { pageCount, page } = await PdfViewer.open({
  source: 'https://example.com/manual.pdf',
  headers: { Authorization: 'Bearer YOUR_TOKEN' },
  mode: 'fullscreen',
  scrollMode: 'continuous',
  page: 1,
});

await PdfViewer.goToPage({ page: 2 });
await PdfViewer.setZoom({ scale: 1.25 });
await PdfViewer.close();
```

**Inline preview** in a div:

```typescript
await PdfViewer.open({
  source: base64FromYourApi,
  sourceType: 'base64',
  mode: 'inline',
  elementId: 'pdf-host',
});
```

**Password-protected file** (iOS and Android):

```typescript
await PdfViewer.open({
  source: '/path/on/device/encrypted.pdf',
  sourceType: 'path',
  password: 'secret',
});
```

On native shells, loading a PDF from the WebView origin URL often fails because that origin is not a real file server. Fetch the bytes in JavaScript and pass `sourceType: 'base64'` instead (see `example-app/`).

## API

<docgen-index>

* [`open(...)`](#open)
* [`close()`](#close)
* [`goToPage(...)`](#gotopage)
* [`setZoom(...)`](#setzoom)
* [`getPluginVersion()`](#getpluginversion)
* [`addListener('load', ...)`](#addlistenerload-)
* [`addListener('pageChange', ...)`](#addlistenerpagechange-)
* [`addListener('error', ...)`](#addlistenererror-)
* [`addListener('close', ...)`](#addlistenerclose-)
* [`addListener('linkTap', ...)`](#addlistenerlinktap-)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capgo PDF Viewer plugin API.

### open(...)

```typescript
open(options: OpenPdfOptions) => Promise<OpenPdfResult>
```

Open a PDF from a file, path, URL, or base64 source.

| Param         | Type                                                      |
| ------------- | --------------------------------------------------------- |
| **`options`** | <code><a href="#openpdfoptions">OpenPdfOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#openpdfresult">OpenPdfResult</a>&gt;</code>

--------------------


### close()

```typescript
close() => Promise<void>
```

Close the active viewer and remove any overlay.

--------------------


### goToPage(...)

```typescript
goToPage(options: GoToPageOptions) => Promise<void>
```

Jump to a 1-based page number.

| Param         | Type                                                        |
| ------------- | ----------------------------------------------------------- |
| **`options`** | <code><a href="#gotopageoptions">GoToPageOptions</a></code> |

--------------------


### setZoom(...)

```typescript
setZoom(options: SetZoomOptions) => Promise<void>
```

Set the zoom scale multiplier (`1` ≈ fit default).
On web this resolves without changing the browser viewer zoom.

| Param         | Type                                                      |
| ------------- | --------------------------------------------------------- |
| **`options`** | <code><a href="#setzoomoptions">SetZoomOptions</a></code> |

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<PluginVersionResult>
```

Get the native/web implementation version marker.

**Returns:** <code>Promise&lt;<a href="#pluginversionresult">PluginVersionResult</a>&gt;</code>

--------------------


### addListener('load', ...)

```typescript
addListener(eventName: 'load', listenerFunc: (event: PdfLoadEvent) => void) => Promise<PluginListenerHandle>
```

Listen for successful PDF load.

| Param              | Type                                                                      |
| ------------------ | ------------------------------------------------------------------------- |
| **`eventName`**    | <code>'load'</code>                                                       |
| **`listenerFunc`** | <code>(event: <a href="#pdfloadevent">PdfLoadEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('pageChange', ...)

```typescript
addListener(eventName: 'pageChange', listenerFunc: (event: PdfPageChangeEvent) => void) => Promise<PluginListenerHandle>
```

Listen for page changes.

| Param              | Type                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'pageChange'</code>                                                             |
| **`listenerFunc`** | <code>(event: <a href="#pdfpagechangeevent">PdfPageChangeEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('error', ...)

```typescript
addListener(eventName: 'error', listenerFunc: (event: PdfErrorEvent) => void) => Promise<PluginListenerHandle>
```

Listen for errors while opening or displaying a PDF.

| Param              | Type                                                                        |
| ------------------ | --------------------------------------------------------------------------- |
| **`eventName`**    | <code>'error'</code>                                                        |
| **`listenerFunc`** | <code>(event: <a href="#pdferrorevent">PdfErrorEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('close', ...)

```typescript
addListener(eventName: 'close', listenerFunc: (event: PdfCloseEvent) => void) => Promise<PluginListenerHandle>
```

Listen for viewer close.

| Param              | Type                                                                        |
| ------------------ | --------------------------------------------------------------------------- |
| **`eventName`**    | <code>'close'</code>                                                        |
| **`listenerFunc`** | <code>(event: <a href="#pdfcloseevent">PdfCloseEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('linkTap', ...)

```typescript
addListener(eventName: 'linkTap', listenerFunc: (event: PdfLinkTapEvent) => void) => Promise<PluginListenerHandle>
```

Listen for taps on links inside the PDF.

| Param              | Type                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'linkTap'</code>                                                          |
| **`listenerFunc`** | <code>(event: <a href="#pdflinktapevent">PdfLinkTapEvent</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### Interfaces


#### OpenPdfResult

Result returned after a PDF successfully opens.

| Prop            | Type                | Description                            |
| --------------- | ------------------- | -------------------------------------- |
| **`pageCount`** | <code>number</code> | Total number of pages in the document. |
| **`page`**      | <code>number</code> | Current page, 1-based.                 |


#### OpenPdfOptions

Options for opening a PDF.

| Prop             | Type                                                            | Description                                                                                                                                                                      | Default                   |
| ---------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **`source`**     | <code>string</code>                                             | PDF location: file URL, device path, https URL, or base64 (raw or `data:` URI).                                                                                                  |                           |
| **`sourceType`** | <code><a href="#pdfsourcetype">PdfSourceType</a></code>         | Explicit source kind. When omitted: - `data:` or raw base64 without a scheme =&gt; `base64` - `http`/`https` =&gt; `url` - otherwise =&gt; `file` (treated like a path/file URL) |                           |
| **`headers`**    | <code><a href="#record">Record</a>&lt;string, string&gt;</code> | HTTP headers used when downloading an https `url` source (e.g. auth cookies).                                                                                                    |                           |
| **`password`**   | <code>string</code>                                             | Password for encrypted PDFs. On web, the password cannot be injected into the browser viewer; the browser may still prompt.                                                      |                           |
| **`mode`**       | <code><a href="#pdfdisplaymode">PdfDisplayMode</a></code>       | How to present the viewer.                                                                                                                                                       | <code>'fullscreen'</code> |
| **`elementId`**  | <code>string</code>                                             | DOM element id used when `mode` is `inline`. Native measures this element and places the viewer over it.                                                                         |                           |
| **`page`**       | <code>number</code>                                             | Initial page, 1-based.                                                                                                                                                           |                           |
| **`scrollMode`** | <code><a href="#pdfscrollmode">PdfScrollMode</a></code>         | Scroll behavior.                                                                                                                                                                 | <code>'continuous'</code> |


#### GoToPageOptions

Options for jumping to a page.

| Prop       | Type                | Description           |
| ---------- | ------------------- | --------------------- |
| **`page`** | <code>number</code> | Target page, 1-based. |


#### SetZoomOptions

Options for changing zoom.

| Prop        | Type                | Description                                        |
| ----------- | ------------------- | -------------------------------------------------- |
| **`scale`** | <code>number</code> | Zoom multiplier. `1` is the fit-ish default scale. |


#### PluginVersionResult

Plugin version payload.

| Prop          | Type                | Description                                                 |
| ------------- | ------------------- | ----------------------------------------------------------- |
| **`version`** | <code>string</code> | Version identifier returned by the platform implementation. |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### PdfLoadEvent

Emitted when the PDF finishes loading.

| Prop            | Type                | Description            |
| --------------- | ------------------- | ---------------------- |
| **`pageCount`** | <code>number</code> | Total number of pages. |
| **`page`**      | <code>number</code> | Current page, 1-based. |


#### PdfPageChangeEvent

Emitted when the visible page changes.

| Prop            | Type                | Description            |
| --------------- | ------------------- | ---------------------- |
| **`page`**      | <code>number</code> | Current page, 1-based. |
| **`pageCount`** | <code>number</code> | Total number of pages. |


#### PdfErrorEvent

Emitted when opening or rendering fails.

| Prop          | Type                | Description                   |
| ------------- | ------------------- | ----------------------------- |
| **`message`** | <code>string</code> | Human-readable error message. |


#### PdfLinkTapEvent

Emitted when the user taps a link inside the PDF.

| Prop      | Type                | Description                         |
| --------- | ------------------- | ----------------------------------- |
| **`url`** | <code>string</code> | Destination URL of the tapped link. |


### Type Aliases


#### PdfSourceType

How the `source` string should be interpreted.
When omitted, the plugin infers the type from the string shape.

<code>'file' | 'path' | 'url' | 'base64'</code>


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>


#### PdfDisplayMode

Presentation mode for the viewer.
- `fullscreen`: covers the app with a native/browser overlay.
- `inline`: places the viewer over a DOM element identified by `elementId`.

<code>'fullscreen' | 'inline'</code>


#### PdfScrollMode

Page scrolling behavior.
- `continuous`: pages flow vertically (or as one scrollable document).
- `single`: one page at a time.

<code>'continuous' | 'single'</code>


#### PdfCloseEvent

Emitted when the viewer is closed.

<code><a href="#record">Record</a>&lt;string, never&gt;</code>

</docgen-api>
