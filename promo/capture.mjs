import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(root, "screenshots");

const BASE = process.env.PROMO_BASE_URL || "https://kiddotasks-app.web.app";

const webDesktop = [
  { url: `${BASE}/`, file: "web-desktop/01-landing-hero.png", wait: 1200 },
  { url: `${BASE}/`, file: "web-desktop/02-landing-full.png", fullPage: true },
  { url: `${BASE}/pricing`, file: "web-desktop/03-pricing.png" },
  { url: `${BASE}/how-to`, file: "web-desktop/04-how-to.png" },
  { url: `${BASE}/blog/summer-missions`, file: "web-desktop/05-summer-guide.png" },
];

const webMobile = [
  { url: `${BASE}/`, file: "web-mobile/01-landing-hero.png" },
  { url: `${BASE}/pricing`, file: "web-mobile/02-pricing.png" },
  { url: `${BASE}/how-to`, file: "web-mobile/03-how-to.png" },
];

const mockups = [
  {
    html: path.join(root, "mockups/parent-today-web.html"),
    file: "product/parent-today-web.png",
    viewport: { width: 1200, height: 920 },
  },
  {
    html: path.join(root, "mockups/rewards-web.html"),
    file: "product/rewards-web.png",
    viewport: { width: 1200, height: 920 },
  },
  {
    html: path.join(root, "mockups/kids-station-iphone.html"),
    file: "ios-framed/kids-station-iphone.png",
    viewport: { width: 560, height: 900 },
  },
  {
    html: path.join(root, "mockups/parent-today-iphone.html"),
    file: "ios-framed/parent-today-iphone.png",
    viewport: { width: 560, height: 900 },
  },
  {
    html: path.join(root, "mockups/celebration-iphone.html"),
    file: "ios-framed/celebration-iphone.png",
    viewport: { width: 560, height: 900 },
  },
];

async function shotUrl(browser, item, viewport) {
  const page = await browser.newPage({ viewport, deviceScaleFactor: 2 });
  await page.goto(item.url, { waitUntil: "networkidle", timeout: 60000 });
  // Allow landing animations to settle
  await page.waitForTimeout(item.wait ?? 600);
  const target = path.join(out, item.file);
  await mkdir(path.dirname(target), { recursive: true });
  await page.screenshot({ path: target, fullPage: Boolean(item.fullPage) });
  await page.close();
  console.log("saved", item.file);
}

async function shotFile(browser, item) {
  const page = await browser.newPage({
    viewport: item.viewport,
    deviceScaleFactor: 2,
  });
  const url = pathToFileURL(item.html).href;
  await page.goto(url, { waitUntil: "networkidle", timeout: 60000 });
  await page.waitForTimeout(400);
  const target = path.join(out, item.file);
  await mkdir(path.dirname(target), { recursive: true });
  const el = page.locator("#shot");
  if (await el.count()) {
    await el.screenshot({ path: target });
  } else {
    await page.screenshot({ path: target, fullPage: true });
  }
  await page.close();
  console.log("saved", item.file);
}

const browser = await chromium.launch({ headless: true });
try {
  console.log("Capturing production web pages from", BASE);
  for (const item of webDesktop) {
    await shotUrl(browser, item, { width: 1440, height: 900 });
  }
  for (const item of webMobile) {
    await shotUrl(browser, item, { width: 390, height: 844 });
  }
  console.log("Capturing product mockups");
  for (const item of mockups) {
    await shotFile(browser, item);
  }
} finally {
  await browser.close();
}
console.log("Done. Output:", out);
