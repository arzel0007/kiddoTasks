# Kiddotasks — UI/UX Enhancement Handover

**Date:** 2026-09-10  
**Status:** Audit complete → Implementation in progress  
**Repo:** main worktree `/Users/arjayresurreccion/projects/GitHub/kiddoTasks`  
**Constraint:** **No decorative gradients anywhere.**

This document is the source of truth if the session loses context. Read it before continuing UI work.

---

## Product goal

Take Kiddotasks from a functional family chore app to a **premium, intentional product**: fast launch, calm parent space, playful kids space, clear feedback, custom forms, night mode — without looking template/AI-generated.

**Priority order:** Usability → Consistency → Performance → Visual polish → Delight.

---

## What already works (do not redesign from zero)

| Asset | Location |
|---|---|
| Design tokens (color, type, spacing, radius, shadow, animation, kids palette, page backgrounds) | `Kiddotasks/Design/KiddotasksDesignTokens.swift` |
| Shared components (buttons, mission card, stat tile, section card, empty state, skeleton, celebration, haptics) | `Kiddotasks/Features/Shared/KiddotasksComponents.swift` |
| Logo / wordmark / family header | `Kiddotasks/Design/KiddotasksLogo.swift` |
| Parent Today dashboard (stat tiles + charts) | `TodayDashboardView.swift` |
| Kids missions / shop / celebration | `KidsStationViews.swift` |
| Dual page backgrounds (light/dark via UIColor traits) | `PageBackgrounds` in tokens |

**Keep:** flat page colors (no gradients), rounded display type, parent vs kids personality, existing motion primitives (`KiddoPressStyle`, `popIn`, `wiggle`, celebration).

---

## Audit findings (why we’re changing things)

### Highest “vibe-coded” risks
1. **Stock iOS Forms** — Task/Reward/Child/Family/Points/auth all use `Form` + `TextField` + `Picker` + `Stepper`.
2. **Splash** — hard **3s** minimum + fake progress (`SplashView.swift`).
3. **No toasts** — outcomes use system alerts; **~38 `try?`** swallow errors.
4. **Night mode incomplete** — page BGs adapt, but **~29 hardcoded whites** on cards/avatars/empty states; **no in-app theme toggle**.
5. **Reward editor has no icon picker** (icon stored but not edited).
6. **Task icon picker** is a 17-symbol grid, no categories.
7. **Who’s playing?** uses one static kids background for all children.
8. **Empty states inconsistent** — lists use gray text; kids stack `FloatingEmoji` + `EmptyStateView`.
9. **No Reduce Motion** handling on infinite animations.
10. **Buttons** lack loading state; no tertiary/destructive system.

### Performance notes
- Forced splash delay is the biggest perceived slow start.
- `ParentCenterViews.swift` is ~1000 lines (maintenance, not necessarily runtime).
- Skeletons only tied to `appState.isLoading`, not real first cloud paint.
- Photo payload size is a sync concern (separate from this UI pass).

---

## Phased plan

| Phase | Scope | Status |
|---|---|---|
| **0** | Full audit | **Done** (this doc + conversation audit) |
| **1** | Night-mode tokens, remove hardcoded whites, theme toggle | **In progress** |
| **2** | Toast system + wire CRUD/approval feedback; reduce silent `try?` | **In progress** |
| **3** | Fast honest splash (no 3s lock; real-ready transition) | **In progress** |
| **4** | Custom form primitives + icon picker v2 (incl. rewards) | Not started |
| **5** | Kids “Who’s playing?” child-tinted background + transition | Not started |
| **6** | Micro-interactions, tab polish, unified empty/loading | Not started |
| **7** | Performance pass (launch, re-renders, skeletons on real loads) | Not started |

### Phase 4+ detail (planned, not implemented)

**Forms**
- `KiddoTextField`, `KiddoTextArea`, `KiddoStepper`/points control, chip segments instead of default pickers where useful.
- Apply to Task, Reward, Child, Family, PIN, Sign up/in/Join.

**Icon picker v2**
- Categories (School, Home, Health, Play, Food, Pets, Rewards…), larger SF Symbol set, selected state, recents.
- Same picker for tasks **and** rewards.

**Kids player screen**
- BG = child accent at low opacity over kids base (controlled palette).
- Short color wash / transition into that child’s station.
- Respect Reduce Motion.

**Motion / a11y**
- Gate infinite bob/sparkle on `accessibilityReduceMotion`.
- Subtle tab content transitions; press depth on parent cards.

---

## Design rules (non-negotiable)

1. **No gradients** for decoration (shimmer skeletons may use opacity pulse instead of linear gradient).
2. Prefer **subtle** motion over loud effects.
3. Parent = calm/trust; Kids = playful, not chaotic.
4. Reuse tokens — no one-off hex on screens when a token exists.
5. Don’t sacrifice usability for aesthetics.
6. No new UI dependency libraries unless justified.

---

## Theme system target (Phase 1)

```
Appearance: system | light | night   (@AppStorage "kiddo.appearance")
```

Token layers to add/extend:
- `background`, `surface`, `surfaceElevated`, `border`
- `text`, `textSecondary`, `textTertiary`
- `primary` / on-primary content
- Kids night variants of `kidsPlayground`, `kidsMissionSky`, `kidsRewardPop`
- Replace `.white` / `Color.white` backgrounds with `surface` / elevated tokens

---

## Toast system target (Phase 2)

- `ToastStyle`: success | error | info  
- `ToastCenter` observable + overlay in `RootView`  
- Auto-dismiss ~2.5s; optional haptic  
- Wire: task/reward create/update/delete, archive/restore, approve/decline, claim, settings, points  
- On store `catch`: show toast (and keep `presentError` as fallback for rare cases)

---

## Splash target (Phase 3)

- Remove `minimumDisplayTime = 3`
- Dismiss when ready, cap ~1.2–1.5s if needed for brand beat
- Progress reflects real steps if cheap to measure; else brief brand animation without fake bar sitting at 47%
- No layout jump into RootView

---

## Current implementation progress

### Completed before this UI pass
- Permanent cloud sync fix (dirty-safe restore, tombstones, forceNewFamily reset recovery)
- Auth error isolation between sheets; post-reset recovery
- Full Firestore orphan wipe for leftover family
- Unit tests green; app builds

### This UI pass (update as you ship)
- [x] Audit documented (`docs/UI_UX_ENHANCEMENT_HANDOVER.md`)
- [x] Phase 1 — semantic surfaces (`surfaceCard` / `surfaceElevated` / `borderSubtle`), skeleton without gradient shimmer, Family → **Appearance** (System / Light / Night)
- [x] Phase 2 — `ToastCenter` + bottom banner in `RootView`; task/reward save, archive, delete, kids mission submit; `AppState.toastSuccess/Error`
- [x] Phase 3 — Splash: no 3s lock; logo settle; exits when ready (min ~0.55s, hard cap 1.4s)
- [x] Phase 4 — Custom form primitives (`KiddoTextField`, `KiddoTextArea`, `KiddoPointsStepper`, `KiddoChipPicker`, `KiddoFormSection`, `FlowLayout`) + categorized `KiddoIconPicker` (tasks & rewards); Task/Reward/Child/Family name/auth/PIN editors rewritten off stock Form chrome
- [x] Phase 5 — Who’s playing: press-preview accent wash on page, stronger player cards, enter-after-beat; Kids Station tabs/missions/shop/badges tinted by child accent; claim uses toasts; Reduce Motion respected
- [x] Phase 6 — Unified `EmptyStateView`/`EmptyListHint` (Today, History, Tasks, Rewards, Kids); Reduce Motion on bob/sparkles/wiggle/press/celebration/skeleton; `CardPressStyle` on parent rows & missions; PointsBadge numeric transition; parent tab haptic; archive/restore/child toasts
- [x] Phase 7 — Performance: `KiddoImageCache` for photo decode; Today aggregates memoized on `dataRevision`; RootView no longer forces full-tree refresh every persist; launch `[Perf]` log; approve/decline toasts; image compressor already caps 400px / 0.6 JPEG

**Build / tests after Phase 1–7:** BUILD SUCCEEDED · TEST SUCCEEDED

### Phase 7 measurement notes
- Console filter: `[Perf] Splash dismissed after …ms`
- Next if needed: Instruments Time Profiler on tab switch; Storage for large photo payloads; optional Firebase Storage for photos (out of UI scope).

### Follow-up polish (post Phase 7)
- [x] Kid points editor on Kiddo form primitives + toasts
- [x] Family photo remove / code copy / child remove toasts
- [x] Splash video: `Boy_riding_rocket_in_space.mp4` (muted, aspect-fill) + brand lockup; logo fallback for missing asset / Reduce Motion; ~6s hard cap
- [x] Firebase Storage for photos: `photoURL` on Child/Family, upload on save when cloud on, push strips embedded `photoData` when URL present, `RemotePhotoView` loader, `Firebase/storage.rules`

**Deploy note:** `firebase deploy --only storage` (and functions if pending). Enable Storage bucket in Firebase console if not already.

**Build / tests after Phase 1–7 + follow-ups:** BUILD SUCCEEDED · TEST SUCCEEDED

### New files
- `Kiddotasks/Design/ThemeStore.swift` — appearance + semantic surfaces
- `Kiddotasks/Features/Shared/Toast.swift` — ToastCenter + banner
- `Kiddotasks/Features/Shared/KiddoFormComponents.swift` — field/chip/stepper/section primitives
- `Kiddotasks/Features/Shared/KiddoIconPicker.swift` — catalog + picker UI
- `Kiddotasks/Features/KidsStation/ChildPlayerTheme.swift` — child accent page theming
- `Kiddotasks/Utilities/KiddoImageCache.swift` — UIImage decode cache

### Suggested PR split
1. **PR1:** Phase 1+2+3 (theme, toast, splash) — **implemented**
2. **PR2:** Phase 4 (forms + icons) — **implemented**
3. **PR3:** Phase 5–6 (kids player + polish) — **implemented**
4. **PR4:** Phase 7 (perf) — **implemented**

---

## How to resume after context loss

1. Read this file + `docs/PROGRESS.md` + `docs/HANDOVER.md` (sync).
2. `git status` / recent commits on `main`.
3. Check checklist above; implement the next unchecked Phase.
4. Build:  
   `DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -project Kiddotasks.xcodeproj -scheme Kiddotasks -destination 'platform=iOS Simulator,name=iPhone 17' build`
5. Keep **no gradients**. Prefer tokens. Ship toast before more decorative motion.

---

## Key files map

| Concern | File |
|---|---|
| Tokens / palette | `Kiddotasks/Design/KiddotasksDesignTokens.swift` |
| Buttons, cards, skeleton, empty | `Kiddotasks/Features/Shared/KiddotasksComponents.swift` |
| Splash | `Kiddotasks/Features/Shared/SplashView.swift` |
| Root mode switch + global error alert | `Kiddotasks/RootView.swift` |
| App state / errors | `Kiddotasks/App/AppState.swift` |
| Parent tabs / editors | `Kiddotasks/Features/ParentCenter/ParentCenterViews.swift` |
| Today | `Kiddotasks/Features/ParentCenter/TodayDashboardView.swift` |
| Kids station / player select | `Kiddotasks/Features/KidsStation/KidsStationViews.swift` |
| Auth | `Kiddotasks/Features/Auth/WelcomeView.swift` |
