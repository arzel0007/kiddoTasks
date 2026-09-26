# Kiddotasks — Store Listing Pack

Publishing metadata + screenshot inventory for the Kiddotasks family chore app.
Source of truth: product copy from `docs/PRODUCT_SPEC.md`, `promo/PROMOTION_PLAN.md`, and `apps/web` billing/plans.

---

## Listing fields

| Field | Value |
|---|---|
| **App name** | **Kiddotasks** |
| **Tag line** | **Missions for kids. Support for parents.** |
| **Website** | **https://kiddotasks-app.web.app** |
| **Categories (3)** | 1. **Productivity** · 2. **Lifestyle** · 3. **Education** (family / kids) |
| **Pricing** | **Freemium** — Free plan stays free · Premium **₱199/month** (cancel anytime) |
| **Platforms** | **iOS / iPadOS** (native SwiftUI, iPhone parents + shared iPad Kids Station) · **Web** (same family space in the browser) |
| **Launch date** | **Web: live (September 2026)** at kiddotasks-app.web.app · **iOS App Store: not yet submitted** (ready for TestFlight / store review) |

> Stated assumption: “launch date” for a store form is the **public availability date**. The web app is already live; the iOS build is feature-complete locally but not on the App Store yet. Use the web date for web directories/Product Hunt, and set the App Store date when the binary is approved.

---

## Short description (≤ 80 chars)

```
Family chores as missions. Kids earn points. Parents stay in control.
```

## Full description

**Kiddotasks** turns household chores into missions kids understand and enjoy.

Parents manage everything from their phone: create chores, set points, approve completions, and watch progress on a clear Today dashboard. Kids open a shared **Kids Station** with a family PIN — no kid email, no passwords, no bank account.

**Why families switch**
- **Missions, not nagging** — daily/weekly routines with stars kids can see
- **No kid accounts** — shared family PIN only
- **Parent approvals** — chore check-offs and reward claims stay under control
- **Honest points** — rewards deduct points only after a parent approves
- **Free plan that stays free** — 1 kid · 20 chores · PIN Kids Station included

**Parent Center**
Today dashboard · tasks CRUD · rewards · kids & avatars · full activity history · notification settings · seasonal themes

**Kids Station**
Missions · points · badges · reward shop · confetti celebrations · mini games

**Optional cloud sync**
Sign in from any parent phone or the shared iPad and keep the whole family in sync.

Upgrade to **Premium (₱199/month)** for co-parent join with a family code, unlimited kids & chores, full history, allowance modes, and week-bonus celebrations. Cancel anytime.

---

## Tags / keywords

```
chores, kids chores, chore chart, family, parenting, rewards, allowance,
kids app, family organizer, routine, habits, points, screen-free, iPad kids
```

**Search keywords (App Store 100-char style):**
```
chores,family,rewards,allowance,kids,routine,habits,points,parenting,chore chart
```

---

## Pricing detail

| Plan | Price | What’s included |
|---|---|---|
| **Free** | **₱0** forever | 1 kid · 20 chores · PIN Kids Station · stars, rewards, games |
| **Premium** | **₱199 / month** | Unlimited kids & chores · co-parent join with family code · full history · allowance modes · week bonus celebrations · priority support · future Premium features |

Billing model: **freemium subscription** (PayMongo recurring; cancel anytime).
Not: one-time paid app · not free-only · not pay-per-feature.

---

## Platforms (for store forms)

| Platform | Detail |
|---|---|
| iPhone | Primary parent device (iOS 18+, SwiftUI) |
| iPad | Shared **Kids Station** (family PIN session) |
| Web app | Same product at `https://kiddotasks-app.web.app` |
| Android | Not shipping at launch |

---

## Age rating / audience notes

- Audience: **parents** manage the app; **children** use Kids Station with permission
- No child email collection · no social features · no advertising
- Suitable for **4+ / Everyone** style family ratings (final rating is store-assigned)

---

## Proof chips (marketing consistent)

- No kid emails
- No bank account
- PIN login
- Free plan stays free

---

## Screenshot pack (`store-assets/screenshots/`)

### A. App Store / store listing (6.7" iPhone — 1290×2796)

| # | File | Story beat |
|---|---|---|
| 1 | `app-store/01-kids-station.png` | Kids Station missions |
| 2 | `app-store/02-parent-today.png` | Parent Center Today |
| 3 | `app-store/03-celebrate.png` | Celebrations & rewards |
| 4 | `app-store/04-rewards-shop.png` | Rewards / shop |
| 5 | `app-store/05-pricing.png` | Free vs Premium |

These are **marketing composites** (branded background + product UI). For formal App Store Connect submission, Apple prefers raw simulator captures without extra marketing chrome — swap in native simulator screenshots when Xcode is available (see `promo/PROMOTION_PLAN.md` §C).

### B. Web / website / press (`web/`)

Desktop 2880×1800 (landing hero, full page, pricing, how-to, summer guide) and mobile 780×1688 (landing, pricing, how-to).

### C. Product UI reference (`product/`)

- Web chrome: `parent-today-web.png`, `rewards-web.png`
- iOS framed mockups: `kids-station-iphone.png`, `parent-today-iphone.png`, `celebration-iphone.png`

---

## Asset rules (keep consistent)

- Brand logo: `apps/web/public/brand-logo.png`
- Palette: primary `#3978a8` · ink `#24364b` · page `#f6f8fa` · reward `#d59a3a` · success `#3f8b70`
- Demo family: **The Santos Family** (fictional). No real child names, no fake testimonials, no invented metrics.

---

## Suggested category mapping

| Store | Category choices |
|---|---|
| Apple App Store | **Productivity** (primary) · **Lifestyle** · **Education** |
| Product Hunt | Productivity · Family · Kids |
| Web directories | Family · Parenting · Productivity |

---

## Ready-to-paste store copy

**Name:** Kiddotasks  
**Subtitle / tag line:** Missions for kids. Support for parents.  
**Promotional text (170 chars):**  
```
Turn chores into missions kids love. PIN-only Kids Station, parent approvals, and a free plan that stays free. Upgrade for co-parents & unlimited kids.
```

**Description:** use “Full description” above.  
**Keywords:** `chores,family,rewards,allowance,kids,routine,habits,points,parenting,chore chart`  
**Support URL:** https://kiddotasks-app.web.app  
**Marketing URL:** https://kiddotasks-app.web.app  
**Privacy policy URL:** _(add before store submission)_  
**Price:** Free with In-App Purchases (Premium ₱199/month)
