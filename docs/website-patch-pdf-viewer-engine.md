# Cap-go/website patch (pdf-viewer WebView Native UI Engine)

Apply on branch `main` of `Cap-go/website`.

## `src/content/docs/docs/plugins/pdf-viewer/index.mdx`

After the inline mode section, add:

````mdx
### Inline mode with WebView Native UI Engine

Set `webViewNativeUiEngine: true` when `mode` is `inline` and you provide `elementId`. The plugin registers the native PDF container with [`@webview-native-ui/engine`](https://github.com/webview-native-ui/engine/) so Web overlays and scroll can coordinate with the native surface.

- Default is `false` (behavior matches previous releases).
- iOS and Android only.
- Use `PdfViewer.signalNativeUiProjection({ destination: 'web' | 'native' | 'none' })` when your HTML covers or uncovers the inline slot.

```typescript
await PdfViewer.open({
  source,
  sourceType: 'base64',
  mode: 'inline',
  elementId: 'pdf-host',
  webViewNativeUiEngine: true,
});

await PdfViewer.signalNativeUiProjection({ destination: 'web' });
// show your modal HTML
await PdfViewer.signalNativeUiProjection({ destination: 'native' });
```
````

## `src/content/docs/docs/plugins/pdf-viewer/getting-started.mdx`

Add a bullet under advanced options:

```md
- **webViewNativeUiEngine** (inline only, default `false`): optional WebView Native UI Engine integration for overlay and scroll coordination.
```

## CocoaPods note in `ios.mdx`

```md
When using `webViewNativeUiEngine`, add a direct npm dependency on `@webview-native-ui/engine@1.0.11` and in the app `Podfile` target (outside `capacitor_pods`):

pod 'WebViewNativeUIEngine', :path => '../../node_modules/@webview-native-ui/engine'
```