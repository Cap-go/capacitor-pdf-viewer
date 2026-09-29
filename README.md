# @capgo/capacitor-pdf-viewer

<a href="https://capgo.app/"><img src="https://capgo.app/readme-banner.svg?repo=Cap-go/capacitor-pdf-viewer" alt="Capgo - Instant updates for Capacitor" /></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_pdf_viewer"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_pdf_viewer"> Missing a feature? We’ll build the plugin for you 💪</a></h2>
</div>

## Snapshot

- **Plugin name:** `PDF Viewer`
- **One-line value:** `Open PDFs inside the app from a file, URL, or base64 string.`
- **Maintainer:** `Capgo`
- **Status:** `alpha`

## Pre-Release Checklist

- [x] Placeholder values in this README are filled in.
- [x] Capgo CTA links use this plugin's ref slug.
- [x] README banner points at this repository.
- [x] `package.json` keywords are filled in.
- [x] Git remote points at this repository.
- [x] Bootstrap init script and templates are removed.
- [x] Compatibility table starts at Capacitor 8.
- [x] Update `src/definitions.ts` with the real public API and JSDoc.
- [x] Run `bun run docgen` and review generated API docs below.
- [x] Confirm examples in this file run against the real implementation.
- [ ] Set GitHub repo description to start with `Capacitor plugin for ...`.
- [x] GitHub homepage is `https://capgo.app/docs/plugins/pdf-viewer/`.
- [ ] Create a GitHub repository custom social preview from `assets/github-social-template.svg`, export it to `assets/github-social-preview.png`, and upload it at GitHub **Settings** -> **General** -> **Social preview**.
- [ ] Open docs/website PR and follow the complete website integration checklist in section **3) Open docs/website pull request**.
- [x] Run `bun run verify` before publishing.

## Problem & Scope

### Why this plugin exists

`WebViews are a poor place to read PDFs. Apps need the system PDF engine, page controls, zoom, and support for password-protected files.`

## Capgo Links

- **Plugin docs URL:** `https://capgo.app/docs/plugins/pdf-viewer/`
- **Plugin tutorial URL:** `https://capgo.app/docs/plugins/pdf-viewer/`
- **Website/docs repo:** `https://github.com/Cap-go/website`

### What it does

- `Opens a PDF from a local file, a device path, an https URL (with custom headers), or base64 data.`
- `Shows the PDF full screen or inside part of the screen, with page navigation, pinch zoom, continuous scrolling, and jump-to-page.`
- `Emits events when the PDF loads, the page changes, an error happens, the viewer closes, or a link is tapped.`

### What it does not do

- `Does not generate or edit PDFs.`
- `Does not download or store a library of documents. It only opens the source you pass in.`

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |
| v7.\*.\*       | v7.\*.\*                | On demand   |
| v6.\*.\*       | v6.\*.\*                | On demand   |

Policy:

- New plugins start at version `8.0.0` (Capacitor 8 baseline).
- Backward compatibility for older Capacitor majors is supported on demand.

## Development

```bash
bun install
bun run verify
```


## Capgo Example App Deploy Setup

The `Deploy example app to Capgo` GitHub Actions workflow publishes the built `example-app/` web bundle to Capgo when a GitHub release is published or the workflow is manually dispatched. It checks out the release tag, builds the plugin and example app with Bun, and uploads the bundle with one direct Capgo CLI command.

Required setup for every plugin created from this template:

1. Create a Capgo app for the example app id from `example-app/capacitor.config.ts`.
   The default id is `app.capgo.pdfviewer.example`; after `bun run init-plugin ...`, verify both `appId` values in that file match the new plugin package id plus `.example`.
2. Keep the Capgo channel named `production`, or edit `.github/workflows/deploy_example_app.yml` if the example app should publish to a different default channel.

`CAPGO_TOKEN` is already configured as a Capgo organization GitHub Actions secret and is read by the workflow through `${{ secrets.CAPGO_TOKEN }}`. Do not create a duplicate repository secret for new plugin repositories.

## Capacitor Hook Scripts (Recommended)

For plugins that need automated setup during `cap sync` / `cap update`, define Capacitor lifecycle hooks in `package.json`.

Example:

```json
{
  "scripts": {
    "generate:version-share": "bun run scripts/generate-version-share-data.mjs",
    "configure:dependencies": "bun run scripts/configure-dependencies.mjs",
    "capacitor:sync:before": "bun run generate:version-share",
    "capacitor:update:before": "bun run generate:version-share",
    "capacitor:sync:after": "bun run configure:dependencies"
  }
}
```

Guideline:
- Use `*:before` for generated inputs needed by native sync/update.
- Use `*:after` for native patching that depends on files created by sync/update.
- Keep hook scripts idempotent.

## Public Launch (Required)

### 1) Publish in Capgo GitHub org as public

```bash
gh repo create Cap-go/capacitor-pdf-viewer --public --source=. --remote=origin --push
```

If the repo already exists and is private:

```bash
gh repo edit Cap-go/capacitor-pdf-viewer --visibility public --accept-visibility-change-consequences
```

### 2) Set GitHub description, homepage, and custom social preview

Description must always start with: `Capacitor plugin for ...`

```bash
gh repo edit Cap-go/capacitor-pdf-viewer \
  --description "Capacitor plugin for opening PDFs inside the app." \
  --homepage "https://capgo.app/docs/plugins/pdf-viewer/"
```

Create the GitHub repository custom social preview before launch. GitHub uses this image for repository cards, link unfurls, and social shares; it is separate from the README banner and website docs images.

1. Open `assets/github-social-template.svg`.
2. Replace the sample headline, accent line, description, and badges with plugin-specific copy.
3. Keep the terminal command as `npm i @capgo/capacitor-pdf-viewer` because social and docs copy should use public npm install syntax.
4. Export the SVG as a 1280 x 640 PNG at `assets/github-social-preview.png`.
5. Have the agent try to upload the PNG in GitHub under repository **Settings** -> **General** -> **Social preview** -> **Edit**.
6. Prefer a supported GitHub API if one exists. GitHub currently does not expose a supported public REST/GraphQL endpoint for this upload, so the practical automation path is an authenticated browser session with repository admin access.
7. If the agent cannot access an authenticated GitHub web session with admin rights, keep `assets/github-social-preview.png` in the repo and report that only the GitHub UI upload is blocked.
8. Do not treat the repository as launch-ready until this custom GitHub social preview is uploaded.
9. Copy targets: headline 4-9 words, accent line 2-6 words, description 60-110 characters, badges 1-3 words each. These are guardrails, not hard failures; the SVG clips longer text inside safe regions, so only shorten copy when the rendered image is hard to read or visibly clipped.

### 3) Open docs/website pull request

Create a PR on `https://github.com/Cap-go/website` (or the local `landing/` folder in the monorepo) with all of the following:

1. Add the plugin entry in `src/config/plugins.ts`.
2. Add a plugin `LinkCard` in `src/content/docs/docs/plugins/index.mdx`.
3. Create docs pages in `src/content/docs/docs/plugins/<plugin-doc-slug>/`:
   `index.mdx`, `getting-started.mdx`, and optionally `ios.mdx` + `android.mdx` when platform setup differs.
4. Update `astro.config.mjs`:
   add `docs/plugins/<plugin-doc-slug>/**` in pagefind path buckets and add a sidebar section for the plugin pages.
5. Add the SEO tutorial page in `src/content/plugins-tutorials/en/<plugin-repo-slug>.md`.
6. Add icon asset `public/icons/plugins/<plugin-doc-slug>.svg` if the docs hero uses a plugin icon.
7. Cross-link docs and tutorial pages.

Slug mapping rules:

- `<plugin-doc-slug>` is the docs route slug used under `/docs/plugins/<plugin-doc-slug>/`.
- `<plugin-repo-slug>` is extracted from the GitHub repo URL in `src/config/plugins.ts` and is used by `/plugins/<slug>/`.
- Example: repo `https://github.com/Cap-go/capacitor-app-attest/` requires tutorial file
  `src/content/plugins-tutorials/en/capacitor-app-attest.md`.

Starter snippets:

`src/config/plugins.ts`

```ts
{
  name: '@capgo/capacitor-pdf-viewer',
  author: 'github.com/Cap-go',
  description: 'Capacitor plugin for opening PDFs inside the app',
  href: 'https://github.com/Cap-go/capacitor-pdf-viewer/',
  title: 'PDF Viewer',
  icon: ShieldCheckIcon,
},
```

`astro.config.mjs` sidebar entry

```ts
{
  label: 'PDF Viewer',
  items: [
    { label: 'Overview', link: '/docs/plugins/<plugin-doc-slug>/' },
    { label: 'Getting started', link: '/docs/plugins/<plugin-doc-slug>/getting-started' },
    { label: 'iOS setup', link: '/docs/plugins/<plugin-doc-slug>/ios' },
    { label: 'Android setup', link: '/docs/plugins/<plugin-doc-slug>/android' },
  ],
  collapsed: true,
},
```

Required docs files:

- `src/content/docs/docs/plugins/<plugin-doc-slug>/index.mdx`
- `src/content/docs/docs/plugins/<plugin-doc-slug>/getting-started.mdx`
- `src/content/docs/docs/plugins/<plugin-doc-slug>/ios.mdx` (if iOS-specific setup exists)
- `src/content/docs/docs/plugins/<plugin-doc-slug>/android.mdx` (if Android-specific setup exists)
- `src/content/plugins-tutorials/en/<plugin-repo-slug>.md`

## Install

You can use our AI-Assisted Setup to install the plugin. Add the Capgo skills to your AI tool using the following command:

```bash
npx skills add https://github.com/cap-go/capacitor-skills --skill capacitor-plugins
```

Then use the following prompt:

```text
Use the `capacitor-plugins` skill from `cap-go/capacitor-skills` to install the `@capgo/capacitor-pdf-viewer` plugin in my project.
```

If you prefer Manual Setup, install the plugin by running the following commands and follow the platform-specific instructions below:

```bash
bun add @capgo/capacitor-pdf-viewer
bunx cap sync
```

## Minimal Usage

```typescript
import { PdfViewer } from '@capgo/capacitor-pdf-viewer';

const result = await PdfViewer.open({
  source: 'https://example.com/document.pdf',
  mode: 'fullscreen',
});
console.log(result.pageCount, result.page);

await PdfViewer.addListener('pageChange', ({ page }) => {
  console.log('page', page);
});
```

## Integration Notes

- **iOS:** Uses Apple PDFKit. Password-protected files unlock with the password you pass to `open`.
- **Android:** Uses Pdfium (`io.legere:pdfiumandroid`) so password-protected files, pinch zoom, and page navigation work. The plugin library manifest does not declare `INTERNET` or storage permissions; your app must already allow network access if you open remote https URLs.
- **Web:** Falls back to the browser's own PDF viewer (`iframe` / blob URL). Custom download headers are applied when fetching URL sources. A `password` cannot be injected into the browser viewer; the browser may still prompt.
## Example App

The `example-app/` folder is linked via `file:..` and is intended for validating native wiring during development.

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
