# Kiddotasks ⭐

A native **iOS family chore app**. Parents manage chores, approvals, rewards,
and activity from their iPhones. Children use a shared iPad Kids Station to
complete missions, watch their points grow, and request rewards — **no child
accounts, no email, no passwords for kids**.

Built with **SwiftUI (iOS 18+)**, local-first with an optional **Firebase
back-end** for real cross-device sync.

## Features

- **Welcome & family setup** — always offers *Sign in* for existing families and
  *Create family*, so switching phones never strands your data.
- **Parent Center** — Today dashboard (stat tiles + weekly charts + per-child
  progress), full **CRUD** for tasks, rewards, children, family settings, Kids
  PIN, approval toggles, and a complete point history.
- **Kids Station** — bright, playful gradients; pick a profile, see missions,
  complete them, earn points, request rewards, collect badges.
- **Approval rules** — rewards always require parent approval (points deducted
  only after approval); tasks use a family default with per-task overrides:
  *always require approval* or *auto-approve*.
- **Cloud sync (optional)** — email/password accounts, family stored in
  Firestore, sign-in restores everything on any device, every change syncs.
- **Dual theme** — clean, colorful Parent Center and a kid-friendly Kids
  Station, with a drawn logo, wordmark, and app icon.

## Screenshots

Run the app in the iOS Simulator: sign up, then the Today dashboard shows the
brand header, stat tiles, the weekly chart, and the Kids-today progress list.

## Tech stack

| Layer | Choice |
|---|---|
| UI | SwiftUI + Observation (`@Observable`, iOS 18) |
| Charts | Swift Charts (`TodayDashboardView`) |
| Persistence | Local snapshot in `UserDefaults` (`LocalFamilyDataStore`) |
| Cloud (optional) | Firebase Auth · Firestore · Functions (email/password) |
| Backend | `Firebase/functions` (TypeScript callables) + `firestore.rules` |

## Project layout

```
Kiddotasks/
  App/AppState.swift                 Root state + cloud-routing
  Models/                            9 Codable models (Family, Child, KiddoTask, …)
  Services/
    LocalFamilyDataStore.swift       Local source of truth + persistence
    Cloud/CloudSyncEngine.swift      Firebase auth + Firestore sync (optional)
    Firebase/                        Firebase config + repos (guarded)
    Repositories/                    Firestore repositories (used when cloud is on)
  Features/                          Auth, ParentCenter, KidsStation, Shared
  Design/                            Design tokens, logo
  Assets.xcassets/                   App icon, accent colors
Firebase/
  firestore.rules                    Security rules (parents only, ledger via functions)
  functions/src/index.ts             bootstrapFamily, pushFamilySnapshot, approvals…
docs/
  PRODUCT_SPEC.md                    Product spec & recorded decisions
  PROGRESS.md                        Feature checklist, status, change log
  FIREBASE_SETUP.md                  Cloud onboarding, step by step
KiddotasksTests/                     Unit tests (17 passing)
```

## Run it locally

Open `Kiddotasks.xcodeproj` in Xcode 16+ and run. No Firebase required — the
app works completely offline/local.

```bash
# CLI build & test (Xcode 16 / Xcode-beta):
xcodebuild -project Kiddotasks.xcodeproj -scheme Kiddotasks \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
```

## Connect the cloud (cross-device sync)

1. Create a Firebase project and register the iOS app with bundle
   `com.kiddotasks.app`.
2. Drop `GoogleService-Info.plist` into the target.
3. Add `firebase-ios-sdk` via Swift Package Manager (Auth, Firestore,
   Functions).
4. Enable **Email/Password** sign-in and deploy the rules + functions:

```bash
firebase use --add
cd Firebase/functions && npm install && cd ../..
firebase deploy --only firestore:rules,functions
```

Full walkthrough: [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

## Status

Phase 0.1–3 features are shipped and tested locally; **Phase 0.2/4 (cloud
sync)** is wired end-to-end in code and just needs a Firebase project + SDK
linkage to go live. See [`docs/PROGRESS.md`](docs/PROGRESS.md) for the feature
checklist, phase table, and dated change log.
