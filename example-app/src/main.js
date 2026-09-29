import './style.css';

import { Capacitor } from '@capacitor/core';
import { PdfViewer } from '@capgo/capacitor-pdf-viewer';
import { CapacitorUpdater } from '@capgo/capacitor-updater';

const output = document.getElementById('plugin-output');
const sampleUrl = new URL('/sample.pdf', window.location.origin).href;

let currentPage = 1;
let pageCount = 1;
let zoom = 1;

const log = (label, value) => {
  const line = typeof value === 'string' ? value : JSON.stringify(value);
  const stamp = new Date().toISOString().slice(11, 19);
  output.textContent = `[${stamp}] ${label}: ${line}\n${output.textContent}`.trim();
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
    log('load', event);
  });
  await PdfViewer.addListener('pageChange', (event) => {
    currentPage = event.page;
    pageCount = event.pageCount;
    log('pageChange', event);
  });
  await PdfViewer.addListener('error', (event) => log('error', event));
  await PdfViewer.addListener('close', () => log('close', {}));
  await PdfViewer.addListener('linkTap', (event) => log('linkTap', event));
};

void wireEvents();

document.getElementById('open-fullscreen').addEventListener('click', async () => {
  try {
    zoom = 1;
    const result = await PdfViewer.open({
      source: sampleUrl,
      sourceType: 'url',
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
    zoom = 1;
    const result = await PdfViewer.open({
      source: sampleUrl,
      sourceType: 'url',
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
