import { defineConfig } from 'vite';

const maestroAutoE2e = process.env.VITE_MAESTRO_AUTO_E2E ?? '';

export default defineConfig({
  define: {
    'import.meta.env.VITE_MAESTRO_AUTO_E2E': JSON.stringify(maestroAutoE2e),
  },
  server: {
    open: true,
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
