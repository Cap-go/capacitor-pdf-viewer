import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const outPath = path.join(root, 'public', 'sample.pdf');

const wrapLines = (text, maxChars) => {
  const words = text.split(/\s+/);
  const lines = [];
  let line = '';
  for (const word of words) {
    const next = line ? `${line} ${word}` : word;
    if (next.length > maxChars) {
      if (line) lines.push(line);
      line = word;
    } else {
      line = next;
    }
  }
  if (line) lines.push(line);
  return lines;
};

const drawParagraph = (page, font, text, x, startY, size, lineHeight, maxChars) => {
  let y = startY;
  for (const line of wrapLines(text, maxChars)) {
    page.drawText(line, { x, y, size, font, color: rgb(0.12, 0.16, 0.22) });
    y -= lineHeight;
  }
  return y;
};

const doc = await PDFDocument.create();
const body = await doc.embedFont(StandardFonts.Helvetica);
const heading = await doc.embedFont(StandardFonts.HelveticaBold);

const page1 = doc.addPage([612, 792]);
page1.drawText('Capacitor PDF Viewer', {
  x: 72,
  y: 704,
  size: 30,
  font: heading,
  color: rgb(0.05, 0.35, 0.62),
});
page1.drawText('Sample document · page 1 of 2', {
  x: 72,
  y: 668,
  size: 14,
  font: body,
  color: rgb(0.35, 0.42, 0.5),
});
drawParagraph(
  page1,
  body,
  'This PDF is bundled with the example app. In underWebView (toBack) mode the native viewer draws these pages full screen while your HTML toolbar floats above a transparent WebView.',
  72,
  620,
  13,
  18,
  72,
);
drawParagraph(
  page1,
  body,
  'Use Prev and Next in the toolbar to move between pages. Pinch or the zoom buttons change scale. The screenshot capture flow uses this file so README images show readable document text behind the overlay.',
  72,
  500,
  13,
  18,
  72,
);

const page2 = doc.addPage([612, 792]);
page2.drawText('Second page', {
  x: 72,
  y: 704,
  size: 26,
  font: heading,
  color: rgb(0.05, 0.35, 0.62),
});
drawParagraph(
  page2,
  body,
  'Page two confirms multi-page navigation. When only the floating toolbar is visible in the WebView, the PDF underneath should remain easy to read without demo buttons or log panels on top.',
  72,
  650,
  13,
  18,
  72,
);
drawParagraph(
  page2,
  body,
  'Swipe horizontally or use the toolbar to return to page one. Close ends the session and restores the example app shell.',
  72,
  560,
  13,
  18,
  72,
);

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, await doc.save());

console.log(`Wrote ${outPath}`);
