# Kiddotasks — Progress Journal

A living record of what the app does, what's shipped, and what comes next.
The product spec lives in [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) and the cloud
setup guide in [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).

## What the app does

Kiddotasks is a native iOS family chore app. Parents run the household from
their iPhones; children use a shared iPad as a "Kids Station".

- **Parents** create families, add child profiles, create tasks (chores),
  approve or decline completions, run a reward shop, review the point history,
  and configure family settings (approval policy, notifications, Kids PIN).
- **Children** pick their profile, see today's missions, complete them, earn
  points, request rewards, and see badges.
- **Core rule**: every reward claim requires parent approval and points are
  only deducted after approval. Task approval uses a family-level default with
  per-task overrides (always require approval / auto-approve).

## Feature checklist (shipped)

- [x] Welcome screen always offers **Sign in** and **Create family**
- [x] Brand identity: drawn logo, wordmark, app icon (gradient star)
- [x] Dual visual theme: playful Kids Station + clean-colorful Parent Center
- [x] Today dashboard with stat tiles, weekly charts, per-child progress
- [x] Full CRUD: tasks (create/edit/archive/restore/delete), rewards,
      children (add/edit/remove), family name, Kids PIN, settings toggles
- [x] Approval workflows: task completion approve/decline, reward claim
      approve/redeem/decline
- [x] Points ledger with audit transactions and balance derivation
- [x] Local persistence (UserDefaults snapshot; survives app restarts)
- [x] Unit tests: points, task-approval behavior, dashboard aggregations, CRUD
      (17 passing)
- [x] Firebase backend scaffold: rules, emulators, callable functions
- [x] **Cloud sync engine** (`CloudSyncEngine`): Auth email/password, family
      bootstrap, pull-on-sign-in, debounced push, live refresh
- [x] **Push notifications** (`NotificationService` + FCM): task submitted /
      approved / rejected, reward requested / approved / rejected, point
      adjustments — full coverage across all family devices
- [ ] Install iPhone/iPad app signed for a device / TestFlight
- [ ] Widgets, Live Activities (notifications shipped; widgets still open)
- [ ] Kids-only iPad session gated by PIN without a parent sign-in

---

## Phase status

| Phase | Intent | Status |
|---|---|---|
| 0.1 Foundation | Models, repos, design tokens, rules, functions | Done |
| 0.2 Project + Auth | Real Xcode project, Firebase, login, routing | Done |
| 1 Kids Station | Child picker → missions → complete → celebrate | Partially built (local) |
| 2 Parent Center | Family, tasks, approval queue, dashboard | Built (local) |
| 3 Rewards | Shop + claims + parent redeem | Built (local) |
| 4 Cloud sync | Auth, Firestore persistence, cross-device | **Deployed — 17 functions ACTIVE (10 core + 7 push), rules live, awaiting first real sign-up** |
| 5 Polish | Tests, a11y, notifications, TestFlight | Notifications **done**; a11y/TestFlight open |

## Change log (dated)

### 2026-09-08 — Push notifications (full family coverage) + FirebaseConfig warning cleanup

Session adds **7 new Cloud Functions** (17 total live) and wires push end-to-end:

**Backend** (`Firebase/functions/src/notifications.ts`, compiled `tsc --strict` green, deployed)
- `notifyOnTaskCompletionCreated` — task awaiting approval + auto-completed tasks → parents
- `notifyOnTaskCompletionUpdated` — approved / rejected → whole family
- `notifyOnRewardClaimCreated` — reward request → parents
- `notifyOnRewardClaimUpdated` — reward approved / rejected → whole family
- `notifyOnPointTransactionCreated` — manual adjustments / bonuses / reversals → whole family
  (skips approval-driven ledger types so approvals don't double-push; 5-min recency guard kills
  first-sync replay storms)
- `registerDeviceToken` / `unregisterDeviceToken` — server-managed `deviceTokens/{fcmToken}` push
  registry (Firestore rules: deny-all for clients; membership validated server-side)

**iOS app**
- `NotificationService` (permission, FCM token upload, unregister on sign-out), `AppDelegate`
  bridging APNs→FCM, `@UIApplicationDelegateAdaptor` in `KiddotasksApp`.
- `Kiddotasks.entitlements` (aps-environment) + `remote-notification` background mode.
- `FirebaseMessaging` SPM product added; `register(completion:)` used (Firebase 12 `fcmToken`
  property is deprecated); `Messaging.apnsToken` fed in `didRegisterForRemoteNotifications`.
- Hooks in `AppState` after sign-in/sign-up. Foreground pushes suppressed (in-app UI already live).
- `FirebaseConfig.swift` `cacheSettings` cleanup (iso); full-build **0 warnings**.
- `firebase deploy --only functions` → 17/17 ACTIVE; `firebase deploy --only firestore:rules` → ✔.

**Docs**: HANDOVER (push matrix + function count + collections incl. `deviceTokens`),
FIREBASE_SETUP (FCM section + APNs key walkthrough), PROGRESS (this entry).

> **One-time setup remaining (user): upload an APNs Auth Key (.p8)** in
> Firebase console → Project settings → Cloud Messaging → APNs Authentication
> Key, then test on a real iPhone/iPad (simulator has no APNs).

### 2026-09-08 — Firebase backend deployed to production + iOS SDK 12 integration

Full session detail in [`HANDOVER.md`](HANDOVER.md). Highlights:

**Cloud (project `kiddotasks-app`, Blaze, Firestore asia-southeast1)**
- Functions deps installed & `tsc --strict` green; `package.json` gained
  `"main": "lib/index.js"` and Node 22 engine.
- Firestore rules fixed (`let` illegal in `match`; `rewards` create/update
  split so creates aren't denied) and deployed.
- All **10 Cloud Functions deployed and ACTIVE** (Node 22, 1st gen,
  us-central1) after riding out a compute-API provisioning lag on the new
  Blaze project; container-image cleanup policy set (1 day).
- Verified live: `bootstrapFamily` probe → `401 UNAUTHENTICATED
  "Must be logged in"`. Remaining check: Email/Password provider enabled.

**iOS app**
- Firebase iOS SDK **12.18.0** via SPM (first packages in the project) +
  `GoogleService-Info.plist` in the Kiddotasks target → cloud mode active.
- `FirebaseConfig` emulator call fixed for SDK 12 (`useEmulator(withHost:port:)`).
- `xcodebuild` **BUILD SUCCEEDED**, 0 errors.
- `GoogleService-Info.plist` unstaged from git (stays local, git-ignored).

**Docs**
- `docs/FIREBASE_SETUP.md` SDK guidance 11→12; new `docs/HANDOVER.md`.

### 2026-09-05 — Cloud sync engine + documentation

Wired the app for Firebase with a fully **local-first fallback**.

**App**
- New `Kiddotasks/Services/Cloud/CloudSyncEngine.swift`:
  - Email/password via Firebase Auth (sign up, sign in, sign out).
  - Sign-up calls the `bootstrapFamily` function and returns the Kids PIN.
  - Sign-in **pulls the entire family down from Firestore** → existing parent
    on a new device sees their data immediately.
  - Every local mutation pushes up automatically (debounced 800 ms) via the
    new `pushFamilySnapshot` callable.
  - Refreshes from the cloud via a `families/{id}` snapshot listener + 20 s
    poll; skips remote apply while unsynced local changes exist.
- `LocalFamilyDataStore`: added `onLocalChanges` hook, `applyRemote`,
  `currentSnapshot`, and `seedLocalFamilyAfterCloudBootstrap` (seeds local
  state with real Firebase IDs).
- `AppState`: holds the engine, routes sign-up/sign-in/sign-out through it when
  Firebase is configured, falls back to the local store otherwise; friendly
  auth error mapping; cloud-aware copy in Welcome/SignIn/SignUp.
- Welcome/SignIn/SignUp screens: loading states, async completion, Kids PIN
  reveal after cloud sign-up, cloud-aware helper text.

**Backend (`Firebase/`)**
- `bootstrapFamily`: generates a random 6-digit Kids Station PIN and returns it.
- New `pushFamilySnapshot` callable: parent-authorized, admin-privileged merge
  of the full family snapshot (children/tasks/completions/rewards/claims/
  transactions/achievements) to keep devices in sync; converts ISO dates to
  Firestore timestamps.

**Docs**
- `README.md` rewritten.
- `docs/FIREBASE_SETUP.md`: full cloud onboarding (project → plist → SPM →
  auth → deploy → run).
- `docs/PROGRESS.md`: this file.

### 2026-09-05 — Interface refresh (5 requested enhancements)

- Welcome always shows **Sign in** + **Create family**.
- Dual theme (Kids Station playful / Parent Center clean).
- Logo mark, wordmark, app icon shipped; brand shown across screens.
- New Today dashboard with stat tiles, Swift Charts weekly graph, per-child
  progress.
- CRUD for tasks, rewards, family/children, Kids PIN, settings.
- 12 new unit tests (17 total passing).

### 2026-08-31 — Phase 0 foundation

- Data model (family, parent, child, task, completion, transaction, reward,
  claim, achievement), local store, design tokens, starter content.
- Firebase rules + emulators + callable functions scaffolded.
- Point balance + task approval behavior tests.

---

## Next steps (ordered)

1. **Activate the cloud**: create the Firebase project, drop in
   `GoogleService-Info.plist`, add the Firebase SPM packages, deploy
   functions/rules (guide: `docs/FIREBASE_SETUP.md`).
2. Reconcile the girls' and parents' flows against the real backend
   (approval functions vs. snapshot push), then tighten conflict handling.
3. Kids-PIN-only iPad session (no parent sign-in) via anonymous auth scoped to
   a family with a PIN proof.
4. Push notifications for parent approvals/activity.
5. Widgets, Live Activities, seasonal themes.
6. TestFlight + a real device install.
7. Sweep: accessibility labels, VoiceOver, dynamic type.