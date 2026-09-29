import type { CapacitorConfig } from '@capacitor/cli';

import pkg from './package.json';

const config: CapacitorConfig = {
  appId: 'app.capgo.pdfviewer',
  appName: '@capgo/capacitor-pdf-viewer',
  webDir: 'dist',
  plugins: {
    CapacitorUpdater: {
      appId: 'app.capgo.pdfviewer',
      autoUpdate: true,
      autoSplashscreen: true,
      directUpdate: 'always',
      defaultChannel: 'production',
      version: pkg.version,
    },
  },
};

export default config;
