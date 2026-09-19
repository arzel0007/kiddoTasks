# Kiddotasks Web App — Promotion Plan

## Goal

Drive sign-ups for the **web app** (`https://kiddotasks-app.web.app`) with a clean screenshot pack that also represents the iOS companion. Messaging centers on: family chores as missions, no kid emails, free plan that stays free, Parent Center + Kids Station.

## Positioning (keep this consistent)

| Element | Copy |
|---|---|
| Product | Kiddotasks |
| Tagline | Missions for kids. Support for parents. |
| Hero | Family chores, made clear |
| Proof chips | No kid emails · No bank account · PIN login · Free plan stays free |
| Pricing | Free ₱0 forever · Premium ₱199/mo |
| URL | kiddotasks-app.web.app |

## Recommended channels (priority)

1. **Website conversion** — hero + social proof of the landing page; pricing clarity.
2. **Parent communities** (Facebook groups, local parenting forums) — 3–5 static images: Kids Station, Parent Today, PIN story, free-vs-premium.
3. **Product Hunt / X / LinkedIn launch post** — desktop web landing + product dashboard + kids phone frame.
4. **App Store later** — when TestFlight/device signing exists, swap framed mockups for native simulator captures. Do not ship mock iOS frames as if they were App Store screenshots.

## Screenshot inventory

### A. Web marketing (live production)

| Shot | Viewport | File | Use |
|---|---|---|---|
| Landing hero | 1440×900 | `screenshots/web-desktop/01-landing-hero.png` | Website, PH, ads |
| Landing full | 1440×full | `screenshots/web-desktop/02-landing-full.png` | Docs, press kit |
| Pricing | 1440×900 | `screenshots/web-desktop/03-pricing.png` | Pricing posts |
| How it works | 1440×900 | `screenshots/web-desktop/04-how-to.png` | Explainer carousels |
| Summer guide | 1440×900 | `screenshots/web-desktop/05-summer-guide.png` | Seasonal content |
| Landing mobile | 390×844 | `screenshots/web-mobile/01-landing-hero.png` | Mobile-first ads |
| Pricing mobile | 390×844 | `screenshots/web-mobile/02-pricing.png` | Stories / vertical |
| How-to mobile | 390×844 | `screenshots/web-mobile/03-how-to.png` | Stories |

### B. Product UI (demo data, Calm Adventure tokens)

Auth-gated parent/kids screens need demo data. This machine has **no Xcode/iOS Simulator**, so native iOS captures are unavailable. We ship **product mockups** that mirror the real web UI + iOS framing for promotion until simulator screenshots exist.

| Shot | Surface | File | Use |
|---|---|---|---|
| Parent Today | Web desktop chrome | `screenshots/product/parent-today-web.png` | Feature posts |
| Rewards / Shop | Web desktop chrome | `screenshots/product/rewards-web.png` | Rewards story |
| Kids Station missions | iPhone frame | `screenshots/ios-framed/kids-station-iphone.png` | “iOS + iPad Kids Station” |
| Parent Today | iPhone frame | `screenshots/ios-framed/parent-today-iphone.png` | Parent phone story |
| Celebration | iPhone frame | `screenshots/ios-framed/celebration-iphone.png` | Emotional hook |

### C. Later (when tooling exists)

- True iOS Simulator captures (Parent Center Today, Tasks, Kids Station, Rewards, History) via Xcode on a machine with full Xcode.
- Optional: short screen recordings for reels (completion → confetti → points).

## Capture method

1. Playwright against **production** for public marketing pages.
2. Playwright against **local promo mockups** (`promo/mockups/*.html`) that reuse brand assets + Calm Adventure tokens for product/iOS frames.
3. Output always under `promo/screenshots/`. Reference only local files in decks/ads.

## Asset rules

- Use real brand logo: `apps/web/public/brand-logo.png`.
- Keep palette: primary `#3978a8`, ink `#24364b`, page `#f6f8fa`, reward `#d59a3a`, success `#3f8b70`.
- No fake testimonials, no invented metrics, no child real names beyond demo personas (Maya, Leo).
- Demo family name: **The Santos Family** (fictional).

## Launch checklist

- [ ] Landing CTA works on mobile
- [ ] `/pricing` free tier remains accurate
- [ ] Screenshot pack reviewed for brand consistency
- [ ] Post copy uses tagline + proof chips
- [ ] Native iOS screenshots queued when Xcode/simulator is available
- [ ] Hosting URL in all captions: `https://kiddotasks-app.web.app`

## Out of scope for this pass

- Paid ads creative variants
- App Store Connect metadata
- Video editing
- Changing product features
