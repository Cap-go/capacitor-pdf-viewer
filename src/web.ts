import { WebPlugin } from '@capacitor/core';

import type { EchoOptions, EchoResult, PdfViewerPlugin, PluginVersionResult } from './definitions';

export class PdfViewerWeb extends WebPlugin implements PdfViewerPlugin {
  async echo(options: EchoOptions): Promise<EchoResult> {
    return options;
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web',
    };
  }
}
