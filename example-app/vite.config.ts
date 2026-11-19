import { defineConfig } from 'vite';

export default defineConfig({
  define: {
    'import.meta.env.VITE_MAESTRO_AUTO_E2E': JSON.stringify(process.env.VITE_MAESTRO_AUTO_E2E ?? ''),
  },
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
