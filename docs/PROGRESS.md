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
- [ ] Install iPhone/iPad app signed for a device / TestFlight
- [ ] Notifications, widgets, Live Activities
- [ ] Kids-only iPad session gated by PIN without a parent sign-in

---

## Phase status

| Phase | Intent | Status |
|---|---|---|
| 0.1 Foundation | Models, repos, design tokens, rules, functions | Done |
| 0.2 Project + Auth | Real Xcode project, Firebase, login, routing | **In progress** |
| 1 Kids Station | Child picker → missions → complete → celebrate | Partially built (local) |
| 2 Parent Center | Family, tasks, approval queue, dashboard | Built (local) |
| 3 Rewards | Shop + claims + parent redeem | Built (local) |
| 4 Cloud sync | Auth, Firestore persistence, cross-device | **New — wired, needs deploy + SDK** |
| 5 Polish | Tests, a11y, notifications, TestFlight | Not started |

## Change log (dated)

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