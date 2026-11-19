import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    open: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    // API 30 emulator WebView (Chrome ~83) cannot parse logical assignment in deps.
    target: 'chrome80',
  },
});
