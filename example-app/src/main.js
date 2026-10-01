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
let customUiActive = false;

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
  customUiActive = visible;
  document.body.classList.toggle('custom-pdf-active', visible);
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
    zoom = event.scale;
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

if (Capacitor.isNativePlatform() && window.location.hash === '#custom-ui') {
  window.setTimeout(() => {
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

document.getElementById('open-fullscreen').addEventListener('click', async () => {
  try {
    setCustomUiVisible(false);
    zoom = 1;
    const result = await PdfViewer.open({
      source: await bundledSample(),
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
    setCustomUiVisible(false);
    zoom = 1;
    const result = await PdfViewer.open({
      source: await bundledSample(),
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
  try {
    setCustomUiVisible(true);
    zoom = 1;
    const result = await PdfViewer.open({
      source: await bundledSample(),
      sourceType: 'base64',
      mode: 'underWebView',
      toBack: true,
      nativeUi: false,
      scrollMode: 'continuous',
      page: 1,
    });
    currentPage = result.page;
    pageCount = result.pageCount;
    refreshCustomIndicator();
    log('open custom ui', result);
  } catch (error) {
    setCustomUiVisible(false);
    log('error', error?.message ?? error);
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
  try {
    await PdfViewer.close();
  } catch (error) {
    log('error', error?.message ?? error);
  }
});
