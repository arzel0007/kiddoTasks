# KiddoTasks — Engineering Handover

**Date:** 2026-09-08 · **Branch:** `main` · **Repo:** <https://github.com/arzel0007/kiddoTasks>

Everything below was executed and verified against the real project — no
assumed state. Companion docs: [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md)
(setup walkthrough), [`PROGRESS.md`](PROGRESS.md) (feature journal),
[`PRODUCT_SPEC.md`](PRODUCT_SPEC.md).

---

## TL;DR — current state

- **App**: builds clean (0 errors, `strict` Swift concurrency on) with the
  Firebase iOS SDK **12.18.0** wired via SPM. Cloud sync engine fully
  integrated: sign-up/sign-in, debounced push, pull-on-sign-in, live listener.
- **Cloud**: Firebase project **`kiddotasks-app`** is live — Firestore
  database (asia-southeast1) with repo security rules deployed, **all 17 Cloud
  Functions ACTIVE** (10 core + **7 push-notification**), Blaze plan,
  container-image cleanup policy set.
- **Push notifications**: full coverage — task submitted/auto-completed/
  approved/rejected, reward requested/approved/rejected, and point
  adjustments. Device tokens are server-managed in `deviceTokens/`
  (`registerDeviceToken` / `unregisterDeviceToken` callables; Firestore rules
  deny client access). The app registers after sign-in and respects the
  family's "Family notifications" toggle (`settings.enableNotifications`).
- **Verified end-to-end at the infra level**: `firebase functions:list` →
  10/10 `ACTIVE`; live probe of `bootstrapFamily` → `401 UNAUTHENTICATED`
  ("Must be logged in"), proving the endpoint runs and is auth-guarded.
- **Only unverified piece**: **Email/Password sign-in provider** — confirm in
  console → Authentication → Sign-in method → Email/Password = Enabled.
  First sign-up fails with `OPERATION_NOT_ALLOWED` if missing.
- **Not yet done**: first git commit of this session's changes; running the
  app to create the real family; pairing the second device.

---

## 1. What was done in this session (chronological)

| # | Work | Result |
|---|---|---|
| 1 | `npm install` in `Firebase/functions` (registry was pathologically slow, ~8 min) | 531 pkgs: `firebase-functions` 4.9.0, `firebase-admin` 11.11.1, `typescript` 5.9.3 |
| 2 | `tsconfig.json`: added `"rootDir": "src"` (TS 5.9 aka.ms/ts6 migration error) | tsc `--strict` build **0 errors** → `lib/index.js` |
| 3 | `package.json`: added missing `"main": "lib/index.js"`; `engines.node` 18→**22** | deploy target matches local Node; nodejs18 runtime retired |
| 4 | Added Firebase iOS SDK via SPM (`firebase-ios-sdk`, resolved **12.18.0**) — project had no packages before | FirebaseAuth, FirebaseFirestore, FirebaseFunctions → Kiddotasks target |
| 5 | `FirebaseConfig.swift`: `Functions.functions().useEmulator(withOrigin:)` doesn't exist in SDK 12 → changed to `useEmulator(withHost: "localhost", port: 5001)` | Full `xcodebuild` → **BUILD SUCCEEDED**, 0 errors |
| 6 | Created/linked Firebase project → `.firebaserc` (git-ignored); verified `GoogleService-Info.plist` matches `com.kiddotasks.app` / project `kiddotasks-app` | plist in Xcode Kiddotasks target |
| 7 | Firestore DB already existed (**asia-southeast1**, production mode). Deployed rules — **fixed 2 real bugs in `Firebase/firestore.rules`**: (a) `let` statements are illegal directly inside `match` blocks (inlined `resource.data.familyId`, 8 occurrences); (b) combined `allow read, create, update` on `rewards` would deny every create because `resource.data` is `null` on create → split into separate `read` / `create` / `update` rules | CLI: "rules file compiled successfully"; rules released ✔ |
| 8 | First functions deploy **failed** for all 10 functions: `compute.googleapis.com` was enabled but its **default compute service account didn't exist yet** (provisioning lag on the brand-new Blaze project) | Verified SA appeared after propagation; redeployed |
| 9 | Redeploy → **all 10 functions "Successful create operation"** | `functions:list`: 10/10 `ACTIVE` |
| 10 | Deploy exited 1 on "could not set up cleanup policy" (post-deploy housekeeping; functions were already live) | `firebase functions:artifacts:setpolicy` → ✔ deletes images older than 1 day |
| 11 | Smoke probes: malformed body → `400 INVALID_ARGUMENT` (endpoint alive); proper callable body `{"data":{}}` → **`401 UNAUTHENTICATED` "Must be logged in"** | Infra verified end-to-end |

---

## 2. Environment facts the next engineer must know

- **Node**: v26.0.0 — functions declare `engines.node: "22"`, so `npm install`
  prints an `EBADENGINE` **warning only**. Deploys use runtime **Node.js 22
  (1st Gen)** and work fine.
- **Xcode is a beta** at `~/Downloads/Xcode-beta.app`, and `xcode-select`
  points at Command Line Tools → plain terminal `xcodebuild` fails. Either run
  `sudo xcode-select -s ~/Downloads/Xcode-beta.app` once, or prefix:
  `env DEVELOPER_DIR=~/Downloads/Xcode-beta.app/Contents/Developer xcodebuild …`
- **Firebase CLI**: firebase-tools 15.26.0 (Homebrew), logged in as
  `xxarzelxx@gmail.com`.
- **npm audit**: 13 vulnerabilities (1 critical) in functions deps — tied to
  the `firebase-functions` v4 line. Fix = upgrade to v6 (breaking changes,
  `onCall` v2 API) — scheduled debt, not blocking.
- Functions are **1st gen** (v1-style `functions.https.onCall` /
  `functions.pubsub.schedule` in `src/index.ts`), region `us-central1`.

---

## 3. Firebase project reference card

| Item | Value |
|---|---|
| Project ID | `kiddotasks-app` |
| iOS bundle ID | `com.kiddotasks.app` |
| `GoogleService-Info.plist` | `Kiddotasks/GoogleService-Info.plist` — **git-ignored, never commit** (contains project identifiers/API keys) |
| Firestore | `(default)`, region **asia-southeast1** (immutable — chosen for PH proximity), production mode + repo rules |
| Auth | Email/Password (the only provider used) — **verify it's Enabled** |
| Plan | Blaze (card on file; free quotas cover this app — expected $0/mo) |
| Functions | 17 × 1st gen (10 core + 7 push), `us-central1`, Node 22 runtime, source `Firebase/functions/src/index.ts` + `notifications.ts` |
| Artifact cleanup | `gcf-artifacts` repo, images >1 day auto-deleted |
| Firestore collections | `families`, `parents`, `children`, `tasks`, `taskCompletions`, `rewards`, `rewardClaims`, `pointTransactions`, `achievements`, `deviceTokens` (push registry — server-only) |

**Data flow recap:** local-first app → every local mutation pushed (800 ms
debounce) via `pushFamilySnapshot` callable → `families/{id}` snapshot listener
+ 20 s poll pull changes back → sign-in on a new device pulls the whole family
→ point ledger is written **only** by Cloud Functions (rules enforce).

### Push-notification coverage

The backend sends an FCM push for every user-facing event; device tokens live
in a server-managed `deviceTokens/{fcmToken}` collection (deny-all in rules —
clients only register through the `registerDeviceToken` / `unregisterDeviceToken`
callables, which validate family membership). Sends respect
`families/{id}.settings.enableNotifications` (the existing toggle).

| # | Event | Backend trigger | Recipients | Message (sample) |
|---|---|---|---|---|
| 1 | Task submitted, needs approval | `notifyOnTaskCompletionCreated` (status `AWAITING_APPROVAL`) | parents | "Maya finished a task — \"Clean room\" needs your approval" |
| 2 | Reward requested | `notifyOnRewardClaimCreated` | parents | "Maya wants a reward — \"Movie night\" (30⭐)" |
| 3 | Task auto-completed (no approval) | `notifyOnTaskCompletionCreated` (status `COMPLETED`) | parents | "Maya completed \"Brush teeth\" (+5⭐)" |
| 4 | Task approved | `notifyOnTaskCompletionUpdated` (→ `APPROVED`) | all family devices | "Task approved ✅ — Maya: \"Clean room\"" |
| 5 | Task rejected | `notifyOnTaskCompletionUpdated` (→ `REJECTED`) | all family devices | "Maya: \"Clean room\" — Parent asked to try again" |
| 6 | Reward approved | `notifyOnRewardClaimUpdated` (→ `APPROVED`) | all family devices | "Reward approved 🎉 — Maya can redeem \"Movie night\"" |
| 7 | Reward rejected | `notifyOnRewardClaimUpdated` (→ `REJECTED`) | all family devices | "Maya: \"Movie night\" — Parent said not this time" |
| 8 | Manual point adjustment / bonus | `notifyOnPointTransactionCreated` (skips `TASK_COMPLETION` / `REWARD_REDEMPTION`) | all family devices | "Points added — Maya +10⭐ — Bonus points" |
| 9 | Point reversal | `notifyOnPointTransactionCreated` (`type == REVERSAL`) | all family devices | "Points deducted — Maya -10⭐ — Reversal of: …" |

Every status transition is deduplicated (the triggers only fire on the
`status` change, never on re-push of the same state), and a **5-minute recency
guard** silences replay storms during first-sync / offline catch-up. The
approval-driven ledger writes are skipped by the point trigger so an approval
produces exactly one push.

On the app side: `NotificationService` asks for permission on first sign-in,
feeds the APNs token into FCM (`Messaging.apnsToken`), uploads the FCM token to
`registerDeviceToken`, and unregisters on sign-out. Foreground pushes are
suppressed (the in-app live UI already shows the change); banners appear when
the app is backgrounded or terminated. Tapping a push opens the app to the
dashboard (deep-linking to specific screens is future work).

### Free-tier local fallback (works without the paid Apple Developer account)

Remote pushes require an APNs auth key, which requires the $99/yr Apple
Developer Program. Until that is set up, the app still banners **locally**:
`CloudSyncEngine.applyFromCloud` diffs each incoming cloud snapshot against
what the device already showed (`FamilyChangeDetector` in
`Kiddotasks/Services/Notifications/`) and fires local notifications via
`LocalFamilyNotifier` for genuinely remote changes (kid actions on another
device, approvals from the other parent). Guardrails mirror the backend:

- Self-made changes never echo back (the diff baseline already contains them).
- The very first pull after sign-in is silent (no replay storm).
- A 5-minute recency window drops stale/offline-catch-up events.
- Approval-driven ledger writes (`TASK_COMPLETION`, `REWARD_REDEMPTION`) are
  skipped so an approval produces exactly one banner.
- Still gated on `settings.enableNotifications` and the OS permission.

Limitation: iOS suspends the app a few minutes after backgrounding, and
nothing can wake a suspended app without APNs — so the fallback covers the
"app open or recently backgrounded" case, while the APNs key (when uploaded)
covers the always-on case. No code changes are needed to activate real push:
upload the `.p8` per `FIREBASE_SETUP.md` and remote pushes take over.


---

## 4. How to run, deploy, verify

```bash
# Daily dev (local-only mode is fine — no plist needed for UI work)
open Kiddotasks.xcodeproj        # ⌘R

# Cloud dev without touching production
firebase emulators:start         # auth :9099, firestore :8080, functions :5001, UI :4000
#   then in Xcode scheme: Environment Variables → FIREBASE_EMULATE = 1

# Deploy backend (idempotent; functions take ~3 min)
./Firebase/setup-database.sh     # login + firebase use --add are prerequisites

# Verify after deploy
firebase functions:list          # expect 10 ACTIVE
curl -s -X POST -H 'Content-Type: application/json' -d '{"data":{}}' \
  https://us-central1-kiddotasks-app.cloudfunctions.net/bootstrapFamily
#   expect: {"error":{"message":"Must be logged in","status":"UNAUTHENTICATED"}}
```

**Multi-device pairing:** Device 1 → Create family (write down the 6-digit
Kids PIN) → add kids/tasks/rewards. Device 2 → Sign in with the same
email/password → whole family pulls down; changes sync both ways (~1 s).

---

## 5. Pending commit — what changed and why

All modifications verified; suggest one commit (or split infra/app):

| File | Why |
|---|---|
| `Firebase/functions/tsconfig.json` | +`rootDir` (TS 5.9 requirement) |
| `Firebase/functions/package.json` | +`"main": "lib/index.js"`, engines node 22 |
| `Firebase/functions/package-lock.json` | **new** — commit for reproducible installs |
| `Firebase/firestore.rules` | fixed illegal `let` in match blocks; rewards create/update split |
| `Kiddotasks/Services/Firebase/FirebaseConfig.swift` | SDK 12 emulator API fix |
| `docs/FIREBASE_SETUP.md`, `Firebase/setup-database.sh` | SDK version guidance 11→12 |
| `Kiddotasks.xcodeproj/project.pbxproj` | SPM firebase-ios-sdk 12.18.0 + plist reference |
| `.gitignore` | +`.firebaserc` |
| `docs/HANDOVER.md`, `docs/PROGRESS.md` | this handover + journal update |
| `Kiddotasks/GoogleService-Info.plist` | **unstaged** (`git rm --cached`) — stays local, ignored |

Suggested message: `Deploy Firebase backend (10 functions, rules) + wire iOS SDK 12; fix rules and emulator API`

---

## 6. Known issues & tech debt (not blocking)

1. **Email/Password provider unverified** (see TL;DR) — 30-second console check.
2. **Sync conflict model**: whole-family snapshots, last-writer-wins per push;
   remote refresh skipped while unsynced local edits exist. Fine for a family;
   per-document conflict resolution is the roadmap item.
3. **firebase-functions v4.9** → upgrade to v6 for audit fixes + Extensions
   support (breaking: v2 `onCall` API in `src/index.ts`).
4. **Cosmetic warnings**: 2 rules warnings (`Unused function:
   getParentFamilyId`, `Invalid function name: get`) and ~13 Swift deprecation
   warnings (e.g. Firestore `cacheSizeBytes`).
5. `.firebaserc` is per-machine (ignored) — new machines run `firebase use --add`.
6. `generateRecurringTasks` scheduled function needs **Cloud Scheduler** (API
   auto-enabled during deploy; first cron run worth watching in console logs).

---

## 7. Security review (2026-09-08, pre-commit)

**Secrets:** ✅ clean. No keys/certs/`.env`/service-account files in the repo. `GoogleService-Info.plist` and `.firebaserc` were **never committed to `main`** (earlier log hits were only dropped stash-index objects; no stashes exist). A stray duplicate plist at the repo root was **deleted**; the real one lives at `Kiddotasks/GoogleService-Info.plist` (git-ignored). iOS API keys in plists are public-by-design; real protection = the Firestore rules.

**Firestore rules:** ✅ solid. Auth-gated everywhere, family-scoped (`parentBelongsToFamily`), field-whitelisted updates (`diff().affectedKeys().hasOnly(...)`), point ledger/claims/achievements read-only to clients (Cloud Functions only), deny-all fallback.

**Cloud Functions — hardened this pass** (all in `Firebase/functions/src/index.ts`, rebuilt clean + redeployed):
1. `pushFamilySnapshot` — **cross-family write (critical, fixed)**: previously wrote any client-supplied doc by ID into shared collections without checking `familyId` (a malicious parent could overwrite another family's docs / forge ledger entries). Now: skips items whose `familyId` mismatches and stamps the validated `familyId` onto every write.
2. `approveTaskCompletion` — client-controlled `pointValue` (fixed): now awards the **task's server-stored `pointValue`**; validates task/completion belong to the caller's family; rejects already-approved completions (no double-award).
3. `approveRewardClaim` — client-controlled `pointCost` + no double-approval guard (fixed): now deducts the **reward's server-stored `pointCost`**; validates claim/reward/child family; rejects already-approved claims (no double-deduction); null-safe points check.
4. `rejectTaskCompletion` / `rejectRewardClaim` — IDOR (fixed): verify the target completion/claim belongs to the caller's family before mutating.
5. `claimReward` — (fixed): validates child and reward belong to the caller's family; required-arg check.

**Remaining known risks (accepted, documented):**
- `npm audit`: 13 vulns (1 critical `uuid` CVSS 7.5, 5 high, 7 moderate) — all server-side in `firebase-functions@4`/`firebase-admin@11` dependency chains. Fix requires `firebase-functions@6` + `firebase-admin@14` (**major** upgrade = v1→v2 API rewrite of `index.ts`). Not exploitable externally in this app's design; scheduled as tech debt.
- Kids Station PIN: 6 digits, stored in the family doc (parents-only readable via rules); generated with `Math.random` (not crypto) — acceptable for its threat model.
- `taskInstances` (written only by the scheduled function via Admin SDK) is covered by the deny-all fallback.


## 8. Troubleshooting matrix (from this session)

| Symptom | Cause → Fix |
|---|---|
| Deploy: "failed to create function …" for every function | compute API/SA provisioning lag on new Blaze project → wait, verify SA exists, redeploy |
| Deploy exit 1: "could not set up cleanup policy" | functions ARE live; run `firebase functions:artifacts:setpolicy` |
| Deploy rejected re: Firestore | database never created (console → Firestore → Create, asia-southeast1) |
| App: `OPERATION_NOT_ALLOWED` on sign-up | Email/Password provider not enabled |
| TS2307 cannot find firebase-functions/admin | `npm install` in `Firebase/functions` |
| TS7006 implicit any on `onCall`/`tx` | cascade of the above — resolves with deps |
| Swift: "Extra argument 'withOrigin'" | firebase-ios-sdk ≥12 → `useEmulator(withHost:port:)` |
| App never goes cloud-mode | plist not in Kiddotasks target (or missing) |
| CLI `xcodebuild` fails | Xcode beta/CLT mismatch → `DEVELOPER_DIR=` prefix (see §2) |
| Red squiggles in Xcode after adding SPM | File → Packages → Reset Package Caches, or restart TS/SPM; CLI build is ground truth |

