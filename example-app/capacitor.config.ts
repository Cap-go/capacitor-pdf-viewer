import type { CapacitorConfig } from '@capacitor/cli';

import pkg from './package.json';

const config: CapacitorConfig = {
  appId: 'app.capgo.pdfviewer',
  appName: '@capgo/capacitor-pdf-viewer',
  webDir: 'dist',
  android: {
    webContentsDebuggingEnabled: true,
  },
  plugins: {
    CapacitorUpdater: {
      appId: 'app.capgo.pdfviewer',
      autoUpdate: false,
      autoSplashscreen: false,
      directUpdate: 'never',
      defaultChannel: 'production',
      version: pkg.version,
    },
  },
};

export default config;
