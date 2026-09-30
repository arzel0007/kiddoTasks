import { chromium } from "playwright";
import { mkdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const frames = path.join(root, "frames");
const html = path.join(root, "ad.html");

const FPS = 30;
const DURATION = 15;
const TOTAL = FPS * DURATION; // 450

await rm(frames, { recursive: true, force: true });
await mkdir(frames, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
});

await page.goto(pathToFileURL(html).href, { waitUntil: "networkidle" });
await page.waitForFunction(() => window.__ready === true, { timeout: 15000 });

console.log(`Capturing ${TOTAL} frames @ ${FPS}fps`);
const t0 = Date.now();
for (let i = 0; i < TOTAL; i++) {
  const t = i / FPS;
  await page.evaluate((tt) => window.seek(tt), t);
  const file = path.join(frames, String(i).padStart(4, "0") + ".png");
  await page.screenshot({ path: file, type: "png" });
  if (i % 30 === 0) {
    const elapsed = (Date.now() - t0) / 1000;
    const rate = (i + 1) / elapsed;
    const eta = (TOTAL - i - 1) / rate;
    console.log(`  frame ${i}/${TOTAL}  t=${t.toFixed(2)}s  ${rate.toFixed(1)} fps  ETA ${eta.toFixed(0)}s`);
  }
}
await browser.close();
console.log("Done in", ((Date.now() - t0) / 1000).toFixed(1), "s");
