import './style.css';

import { Capacitor } from '@capacitor/core';
import { PdfViewer } from '@capgo/capacitor-pdf-viewer';
import { CapacitorUpdater } from '@capgo/capacitor-updater';

const output = document.getElementById('plugin-output');
const sampleUrl = new URL('/sample.pdf', window.location.origin).href;
const customUi = document.getElementById('custom-pdf-ui');
const customPageIndicator = document.getElementById('custom-page-indicator');

const bundledSample = async () => {
  const response = await fetch(sampleUrl);
  if (!response.ok) {
    throw new Error(`Failed to load sample PDF (${response.status})`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
};

let currentPage = 1;
let pageCount = 1;
let zoom = 1;
let demoOpenGeneration = 0;
let autoOpenCustomUiTimer = null;

const cancelAutoOpenCustomUi = () => {
  if (autoOpenCustomUiTimer != null) {
    window.clearTimeout(autoOpenCustomUiTimer);
    autoOpenCustomUiTimer = null;
  }
};

const setCustomCloseEnabled = (enabled) => {
  const closeButton = document.getElementById('custom-close');
  if (closeButton) {
    closeButton.disabled = !enabled;
  }
};

const invalidateCustomUiOpen = () => {
  demoOpenGeneration += 1;
};

const e2eStatus = document.getElementById('e2e-status');
const e2eNativeBg = document.getElementById('e2e-native-bg');

const mirrorE2eHarness = async (text) => {
  if (!Capacitor.isNativePlatform()) {
    return;
  }
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      await PdfViewer.setE2eHarnessLabel({ text });
      return;
    } catch (error) {
      if (attempt === 7) {
        console.warn('setE2eHarnessLabel failed', error);
        return;
      }
      await new Promise((resolve) => window.setTimeout(resolve, 250));
    }
  }
};

const setE2eStatus = async (text) => {
  if (e2eStatus) {
    e2eStatus.textContent = text;
  }
  log('e2e', text);
  console.info(`CAPGO_E2E ${text}`);
  await mirrorE2eHarness(text);
};

const setE2eNativeBgLabel = (hex) => {
  const label = `E2E native bg: ${hex}`;
  if (e2eNativeBg) {
    e2eNativeBg.textContent = label;
  }
  console.info(`CAPGO_E2E ${label}`);
  void mirrorE2eHarness(label);
};

const log = (label, value) => {
  const line = typeof value === 'string' ? value : JSON.stringify(value);
  const stamp = new Date().toISOString().slice(11, 19);
  output.textContent = `[${stamp}] ${label}: ${line}\n${output.textContent}`.trim();
};

const refreshCustomIndicator = () => {
  if (customPageIndicator) {
    customPageIndicator.textContent = `${currentPage} / ${pageCount}`;
  }
};

const setCustomUiVisible = (visible) => {
  document.documentElement.classList.toggle('custom-pdf-active', visible);
  document.body.classList.toggle('custom-pdf-active', visible);
  if (!visible) {
    document.documentElement.classList.remove('custom-pdf-capture-ready');
  }
  document.documentElement.style.background = visible ? 'transparent' : '';
  document.body.style.background = visible ? 'transparent' : '';
  const shell = document.getElementById('demo-shell');
  if (shell) {
    shell.hidden = visible;
    shell.setAttribute('aria-hidden', visible ? 'true' : 'false');
  }
  if (customUi) {
    customUi.hidden = !visible;
    customUi.setAttribute('aria-hidden', visible ? 'false' : 'true');
  }
};

if (Capacitor.isNativePlatform()) {
  void CapacitorUpdater.notifyAppReady().catch((error) => {
    console.error('CapacitorUpdater.notifyAppReady failed', error);
  });
}

const wireEvents = async () => {
  await PdfViewer.addListener('load', (event) => {
    currentPage = event.page;
    pageCount = event.pageCount;
    refreshCustomIndicator();
    log('load', event);
  });
  await PdfViewer.addListener('pageChange', (event) => {
    currentPage = event.page;
    pageCount = event.pageCount;
    refreshCustomIndicator();
    log('pageChange', event);
  });
  await PdfViewer.addListener('zoomChange', (event) => {
    zoom = Math.min(4, Math.max(0.5, event.scale));
    log('zoomChange', event);
  });
  await PdfViewer.addListener('error', (event) => log('error', event));
  await PdfViewer.addListener('close', () => {
    setCustomUiVisible(false);
    log('close', {});
  });
  await PdfViewer.addListener('linkTap', (event) => log('linkTap', event));
};

void wireEvents();

const shouldAutoOpenCustomUi =
  Capacitor.isNativePlatform() &&
  (import.meta.env.VITE_CAPTURE_CUSTOM_UI === 'true' ||
    window.location.hash === '#custom-ui' ||
    new URLSearchParams(window.location.search).get('demo') === 'custom-ui');

if (shouldAutoOpenCustomUi) {
  if (import.meta.env.VITE_CAPTURE_CUSTOM_UI === 'true') {
    document.documentElement.classList.add('custom-pdf-capture-ready');
    setCustomUiVisible(true);
  }
  autoOpenCustomUiTimer = window.setTimeout(() => {
    autoOpenCustomUiTimer = null;
    document.getElementById('open-custom-ui')?.click();
  }, 1200);
}

if (!Capacitor.isNativePlatform()) {
  const urlButton = document.getElementById('open-url');
  urlButton.hidden = false;
  urlButton.addEventListener('click', async () => {
    try {
      zoom = 1;
      const result = await PdfViewer.open({
        source: sampleUrl,
        sourceType: 'url',
        mode: 'fullscreen',
        page: 1,
      });
      currentPage = result.page;
      pageCount = result.pageCount;
      log('open url', result);
    } catch (error) {
      log('error', error?.message ?? error);
    }
  });
}

const openFullscreenFromSource = async (source, options = {}) => {
  zoom = 1;
  const result = await PdfViewer.open({
    source,
    sourceType: 'base64',
    mode: 'fullscreen',
    page: 1,
    scrollMode: 'continuous',
    ...options,
  });
  currentPage = result.page;
  pageCount = result.pageCount;
  return result;
};

const withE2eTimeout = (promise, label) => {
  const ms = 20_000;
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      window.setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
    }),
  ]);
};

const openE2eFromSource = async (source, options = {}) => {
  const result = await PdfViewer.open({
    source,
    sourceType: 'base64',
    mode: 'inline',
    elementId: 'inline-pdf',
    page: 1,
    scrollMode: 'continuous',
    nativeUi: false,
    ...options,
  });
  currentPage = result.page;
  pageCount = result.pageCount;
  return result;
};

const normalizeArgbHex = (hex) => hex.trim().toLowerCase();

const expectNativeBackground = async (expectedArgb) => {
  await new Promise((resolve) => window.setTimeout(resolve, 150));
  const { color } = await PdfViewer.getViewerBackgroundColor();
  const got = normalizeArgbHex(color);
  const want = normalizeArgbHex(expectedArgb);
  if (got !== want) {
    throw new Error(`native bg ${got} expected ${want}`);
  }
  setE2eNativeBgLabel(got);
  return got;
};

const androidDefaultCanvas = '#ff000000';

const defaultCanvasArgb = () => {
  if (Capacitor.getPlatform() === 'android') {
    return androidDefaultCanvas;
  }
  return null;
};

const runE2eOpenWithColor = async () => {
  if (!Capacitor.isNativePlatform()) {
    await setE2eStatus('E2E: native only');
    return false;
  }
  await setE2eStatus('E2E: running open-with-color');
  try {
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    const source = await bundledSample();
    await withE2eTimeout(
      openE2eFromSource(source, { backgroundColor: '#224466' }),
      'open-with-color',
    );
    await expectNativeBackground('#ff224466');
    await PdfViewer.setBackgroundColor({ color: '#335577' });
    await expectNativeBackground('#ff335577');
    await PdfViewer.close();
    await setE2eStatus('E2E: set-bg-while-open ok #ff335577');
    await setE2eStatus('E2E: open-with-color ok');
    return true;
  } catch (error) {
    await PdfViewer.close().catch(() => {});
    await setE2eStatus(`E2E: failed ${error?.message ?? error}`);
    return false;
  }
};

const runE2eOpenWithoutColor = async () => {
  if (!Capacitor.isNativePlatform()) {
    await setE2eStatus('E2E: native only');
    return false;
  }
  await setE2eStatus('E2E: running open-without-color');
  try {
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    const source = await bundledSample();
    await withE2eTimeout(openE2eFromSource(source), 'open-without-color');
    const fallback = defaultCanvasArgb();
    if (fallback) {
      await expectNativeBackground(fallback);
    } else {
      const { color } = await PdfViewer.getViewerBackgroundColor();
      setE2eNativeBgLabel(normalizeArgbHex(color));
      if (normalizeArgbHex(color) === '#ff224466') {
        throw new Error('default open still shows custom color');
      }
    }
    await PdfViewer.close();
    await setE2eStatus('E2E: open-without-color ok');
    return true;
  } catch (error) {
    await PdfViewer.close().catch(() => {});
    await setE2eStatus(`E2E: failed ${error?.message ?? error}`);
    return false;
  }
};

const runE2eInvalidColors = async () => {
  if (!Capacitor.isNativePlatform()) {
    await setE2eStatus('E2E: native only');
    return false;
  }
  await setE2eStatus('E2E: running invalid-colors');
  try {
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    const source = await bundledSample();
    await withE2eTimeout(
      openE2eFromSource(source, { backgroundColor: 'not-a-color' }),
      'invalid-color-open',
    );
    const fallback = defaultCanvasArgb() ?? null;
    if (fallback) {
      await expectNativeBackground(fallback);
    }
    let rejected = false;
    try {
      await PdfViewer.setBackgroundColor({ color: 'bad' });
    } catch (setError) {
      rejected = /invalid color/i.test(String(setError?.message ?? setError));
    }
    await PdfViewer.close();
    if (!rejected) {
      await setE2eStatus('E2E: invalid setBackgroundColor not rejected');
      return false;
    }
    await setE2eStatus('E2E: invalid-color ok');
    return true;
  } catch (error) {
    await PdfViewer.close().catch(() => {});
    await setE2eStatus(`E2E: failed ${error?.message ?? error}`);
    return false;
  }
};

const runE2eRelaunchDefault = async () => {
  if (!Capacitor.isNativePlatform()) {
    await setE2eStatus('E2E: native only');
    return false;
  }
  await setE2eStatus('E2E: running relaunch-default');
  try {
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    const source = await bundledSample();
    await withE2eTimeout(openE2eFromSource(source), 'relaunch-default');
    const fallback = defaultCanvasArgb();
    if (fallback) {
      await expectNativeBackground(fallback);
    } else {
      const { color } = await PdfViewer.getViewerBackgroundColor();
      setE2eNativeBgLabel(normalizeArgbHex(color));
    }
    await PdfViewer.close();
    await setE2eStatus('E2E: relaunch default ok');
    return true;
  } catch (error) {
    await PdfViewer.close().catch(() => {});
    await setE2eStatus(`E2E: failed ${error?.message ?? error}`);
    return false;
  }
};

const runMaestroAutoE2e = async () => {
  await new Promise((resolve) => window.setTimeout(resolve, 400));
  await setE2eStatus('E2E: auto start');
  const steps = [runE2eOpenWithColor, runE2eOpenWithoutColor, runE2eInvalidColors];
  for (const step of steps) {
    const ok = await step();
    if (!ok) {
      return;
    }
  }
  await PdfViewer.setE2eHarnessState({ autoPassComplete: true });
  await setE2eStatus('E2E: auto pass complete');
};

document.getElementById('e2e-open-with-color')?.addEventListener('click', () => {
  void runE2eOpenWithColor();
});

document.getElementById('e2e-open-without-color')?.addEventListener('click', () => {
  void runE2eOpenWithoutColor();
});

document.getElementById('e2e-invalid-colors')?.addEventListener('click', () => {
  void runE2eInvalidColors();
});

document.getElementById('e2e-relaunch-default')?.addEventListener('click', () => {
  void runE2eRelaunchDefault();
});

document.getElementById('open-fullscreen').addEventListener('click', async () => {
  try {
    const openGeneration = ++demoOpenGeneration;
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    zoom = 1;
    const source = await bundledSample();
    if (openGeneration !== demoOpenGeneration) {
      return;
    }
    const result = await PdfViewer.open({
      source,
      sourceType: 'base64',
      mode: 'fullscreen',
      page: 1,
      scrollMode: 'continuous',
    });
    currentPage = result.page;
    pageCount = result.pageCount;
    log('open fullscreen', result);
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('open-inline').addEventListener('click', async () => {
  try {
    const openGeneration = ++demoOpenGeneration;
    cancelAutoOpenCustomUi();
    setCustomUiVisible(false);
    zoom = 1;
    const source = await bundledSample();
    if (openGeneration !== demoOpenGeneration) {
      return;
    }
    const result = await PdfViewer.open({
      source,
      sourceType: 'base64',
      mode: 'inline',
      elementId: 'inline-pdf',
      page: 1,
      scrollMode: 'continuous',
    });
    currentPage = result.page;
    pageCount = result.pageCount;
    log('open inline', result);
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('open-custom-ui').addEventListener('click', async () => {
  if (!Capacitor.isNativePlatform()) {
    log('error', 'Custom UI (toBack) requires iOS or Android');
    return;
  }
  cancelAutoOpenCustomUi();
  const openGeneration = ++demoOpenGeneration;
  setCustomCloseEnabled(false);
  try {
    setCustomUiVisible(true);
    zoom = 1;
    const source = await bundledSample();
    if (openGeneration !== demoOpenGeneration) {
      return;
    }
    const result = await PdfViewer.open({
      source,
      sourceType: 'base64',
      mode: 'underWebView',
      toBack: true,
      nativeUi: false,
      scrollMode: 'continuous',
      page: 1,
    });
    if (openGeneration !== demoOpenGeneration) {
      return;
    }
    currentPage = result.page;
    pageCount = result.pageCount;
    refreshCustomIndicator();
    log('open custom ui', result);
  } catch (error) {
    if (openGeneration !== demoOpenGeneration) {
      return;
    }
    setCustomUiVisible(false);
    log('error', error?.message ?? error);
  } finally {
    if (openGeneration === demoOpenGeneration) {
      setCustomCloseEnabled(true);
    }
  }
});

document.getElementById('prev-page').addEventListener('click', async () => {
  try {
    await PdfViewer.goToPage({ page: Math.max(1, currentPage - 1) });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('next-page').addEventListener('click', async () => {
  try {
    await PdfViewer.goToPage({ page: Math.min(pageCount, currentPage + 1) });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('jump-page').addEventListener('click', async () => {
  try {
    await PdfViewer.goToPage({ page: 2 });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('zoom-in').addEventListener('click', async () => {
  try {
    zoom = Math.min(4, zoom + 0.25);
    await PdfViewer.setZoom({ scale: zoom });
    log('zoom', { scale: zoom });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('close-pdf').addEventListener('click', async () => {
  try {
    await PdfViewer.close();
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('get-version').addEventListener('click', async () => {
  try {
    log('version', await PdfViewer.getPluginVersion());
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('custom-prev').addEventListener('click', async () => {
  try {
    await PdfViewer.previousPage();
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('custom-next').addEventListener('click', async () => {
  try {
    await PdfViewer.nextPage();
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('custom-zoom-out').addEventListener('click', async () => {
  try {
    zoom = Math.max(0.5, zoom - 0.25);
    await PdfViewer.setZoom({ scale: zoom });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('custom-zoom-in').addEventListener('click', async () => {
  try {
    zoom = Math.min(4, zoom + 0.25);
    await PdfViewer.setZoom({ scale: zoom });
  } catch (error) {
    log('error', error?.message ?? error);
  }
});

document.getElementById('custom-close').addEventListener('click', async () => {
  cancelAutoOpenCustomUi();
  invalidateCustomUiOpen();
  setCustomCloseEnabled(false);
  try {
    await PdfViewer.close();
    setCustomUiVisible(false);
  } catch (error) {
    log('error', error?.message ?? error);
  } finally {
    setCustomCloseEnabled(true);
  }
});

if (Capacitor.isNativePlatform()) {
  void (async () => {
    await mirrorE2eHarness('E2E: idle');
  })();
}

if (import.meta.env.VITE_MAESTRO_AUTO_E2E === '1' && Capacitor.isNativePlatform()) {
  console.info('CAPGO_E2E E2E: js module ready');
  void (async () => {
    try {
      const state = await PdfViewer.getE2eHarnessState();
      if (state.autoPassComplete) {
        await setE2eStatus('E2E: idle');
        return;
      }
    } catch (error) {
      console.warn('getE2eHarnessState unavailable; running auto E2E', error);
    }
    try {
      await runMaestroAutoE2e();
    } catch (error) {
      await setE2eStatus(`E2E: failed ${error?.message ?? error}`);
    }
  })();
}