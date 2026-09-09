# Kiddotasks — Firebase Cloud Setup Guide

The app is **local-first by default**: without Firebase it stores your family in a
preferences file inside the app sandbox, and "sign in" only opens the family
that exists on *that* device.

Connecting Firebase upgrades the app to **cloud mode**:

- Email + password accounts via Firebase Authentication.
- Your family (tasks, rewards, points, history) stored in Cloud Firestore.
- Sign in on a **new phone or iPad** and your whole family is pulled down
  automatically — no local copy needed.
- Every change pushes up to the cloud and refreshes back down, so parent
  phones and the kids' iPad stay in sync.

This guide walks through the one-time setup, from creating a Firebase project
to deploying the backend that already ships in this repo.

---

## 1. Create a Firebase project

1. Go to <https://console.firebase.google.com> and sign in with your Google account.
2. **Add project** → name it `kiddotasks` (or anything you like).
   - Analytics is optional; you can enable it or skip it.

## 2. Register the iOS app

1. In the Firebase console, open your project → project **Overview** →
   the **iOS** icon (`+` to add an app).
2. **Bundle ID**: use exactly `com.kiddotasks.app`.
   - App nickname: `Kiddotasks`.
   - Add App Store ID only if/when you have one; you can leave it blank.
3. Download the generated **`GoogleService-Info.plist`**.

## 3. Add the plist to the Xcode project

1. Drag `GoogleService-Info.plist` into Xcode, into the **Kiddotasks** group.
2. Make sure the target checkmark **Kiddotasks** is selected (not just the
   tests). It must be copied into the app bundle.
3. Confirm in the build settings that the file is in Copy Bundle Resources.

> The app only initializes Firebase when this file is present
> (`KiddotasksApp.init` checks `Bundle.main.url(forResource: "GoogleService-Info",
> withExtension: "plist")`). Without it the app stays local-only — safe to
> develop offline.

## 4. Add the Firebase SDK (Swift Package Manager)

1. In Xcode: **File → Add Package Dependencies…**
2. Paste: `https://github.com/firebase/firebase-ios-sdk`
3. Dependency rule: **Up to Next Major Version**, `12.0.0`.
4. Add the products:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFunctions`
   - `FirebaseMessaging` (required for push notifications)
   - (optional) `FirebaseAnalytics`, `FirebaseCrashlytics`
5. Add to the **Kiddotasks** target.
6. Build once so Xcode resolves the packages (this downloads the SDK — needs
   internet the first time).

The Xcode project uses a synchronized folder group, so
`Kiddotasks/Services/Cloud/CloudSyncEngine.swift` is compiled automatically —
no project-file changes are needed to add cloud code.

## 5. Enable Authentication providers

1. Firebase console → **Build → Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Save.

## 6. Deploy the backend

The cloud functions and Firestore rules live in `Firebase/` in this repo.

1. Install the [Firebase CLI](https://firebase.google.com/docs/cli) and log in:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. In the repo root, tell the CLI about your project (once):
   ```bash
   firebase use --add
   # pick your project (e.g. kiddotasks)
   ```
   This creates a `.firebaserc` file (do not commit it).
3. Install function dependencies:
   ```bash
   cd Firebase/functions && npm install && cd ../..
   ```
4. Deploy rules and functions:
   ```bash
   firebase deploy --only firestore:rules,functions
**What gets deployed:**

| Piece | File | Role |
|---|---|---|
| Firestore security rules | `Firebase/firestore.rules` | Parents only; kids data protected; ledger writes restricted to Cloud Functions |
| `bootstrapFamily` | `Firebase/functions/src/index.ts` | Creates `families/{id}` + `parents/{uid}` after sign-up, returns the Kids PIN |
| `pushFamilySnapshot` | `Firebase/functions/src/index.ts` | The app pushes local changes here; writes with admin privileges |
| `createChildProfile`, approvals, claims | `Firebase/functions/src/index.ts` | Server-enforced task approval + reward point transactions |
| `generateRecurringTasks` | `Firebase/functions/src/index.ts` | Midnight scheduler for daily/weekday/weekly chores |

## 7. Run the app

1. Build and run in Xcode.
2. **Create family** → a Firebase account is created and the family is
   bootstrapped in Firestore. The **Kids Station PIN** is shown after sign-up.
3. **Sign in** on any other device with the same email/password → the family
   is pulled from the cloud.
4. Make a change (add a task, approve a completion) → it pushes up (debounced
   ~1s) and refreshes down on the other device (family-doc listener + 20s poll).

## Push notifications

This app uses Firebase Cloud Messaging (FCM) for push — when a kid completes a
task, requests a reward, or a parent approves/rejects something, all family
devices with the app installed get a banner **even when the app is closed**.

**Server side** (already deployed in this repo):

| Event | FCM trigger | Message |
|---|---|---|
| Kid submits a task (approval needed) | `notifyOnTaskCompletionCreated` | "Maya finished a task — \"Clean room\" needs your approval" |
| Kid submits auto-approved task | `notifyOnTaskCompletionCreated` | "Maya completed \"Brush teeth\" (+5⭐)" |
| Parent approves a task | `notifyOnTaskCompletionUpdated` | "Task approved ✅ — Maya: \"Clean room\"" |
| Parent rejects a task | `notifyOnTaskCompletionUpdated` | "Task needs another try — Maya: \"Clean room\"" |
| Kid requests a reward | `notifyOnRewardClaimCreated` | "Maya wants a reward — \"Movie night\" (30⭐)" |
| Reward approved | `notifyOnRewardClaimUpdated` | "Reward approved 🎉 — Maya can redeem \"Movie night\"" |
| Reward rejected | `notifyOnRewardClaimUpdated` | "Reward request declined — Maya: \"Movie night\"" |
| Points adjusted manually / bonus | `notifyOnPointTransactionCreated` | "Points added — Maya +10⭐ — Bonus points" |

Device tokens are stored server-side in `deviceTokens/{fcmToken}` (managed
exclusively by the `registerDeviceToken` / `unregisterDeviceToken` callables —
clients never write that collection directly, and Firestore rules deny it).

**APNs key (one-time setup, required for real devices):**
1. Apple Developer → Certificates, Identifiers & Profiles → **Keys** → **+**.
2. Enable **Apple Push Notifications service (APNs)** → keep the **Key ID** and
   download the **`.p8`** file.
3. Firebase console → your project → **Project settings → Cloud Messaging** →
   **Apple app configuration → APNs Authentication Key → Upload**.
   - Pick the team, paste the Key ID, and upload the `.p8`.
4. The app's `Kiddotasks.entitlements` already includes
   `aps-environment` + the `remote-notification` background mode; Xcode
   automatic signing provisions the cert.

**Testing on the iOS Simulator:** APNs tokens have not worked on simulators
historically; use a **real iPhone/iPad** to verify pushes.

## Offline / local development

- Without the plist or the SDK, the app is 100% local — all existing flows and
  tests keep working (this is what the CI/build checks exercise).
- The sync engine (`CloudSyncEngine`) is the only entry point for cloud use and
  is a no-op when Firebase isn't linked/configured.

## Security model (brief)

- Firestore rules require a signed-in parent for every family read/write.
  Children have **no accounts**; the shared **Kids Station PIN** gates guest
  sessions. In the current MVP the iPad Kids Station runs while a parent is
  signed in on that device (same family).
- Point ledger writes (`pointTransactions`) are restricted to Cloud Functions;
  the app reconciles through `pushFamilySnapshot`, which validates the caller
  is a member parent before writing with admin privileges.
- `parents/{uid}` can only be created by `bootstrapFamily`, and only the owner's
  `displayName`/`lastSignInAt` can be updated by the client.

## Emulators

The root `firebase.json` is configured for local emulation:

```bash
firebase emulators:start     # auth :9099, firestore :8080, functions :5001
```

To point the app at emulators instead of the cloud (for development), set the
emulator wiring in `FirebaseConfig.useEmulatorsIfRequested()`
(`Kiddotasks/Services/Firebase/FirebaseConfig.swift`) — set `FIREBASE_EMULATE=1`
in the scheme's environment variables before running.

## Sync behavior (known, documented limits)

- The engine compares snapshots by a SHA-256 fingerprint; local changes bump a
  revision and are pushed after ~800 ms; remote refresh only applies when there
  are no unsynced local changes, so simultaneous edits from two parents converge
  to last-writer-wins per snapshot.
- Per-document conflict resolution and the kids-PIN-only iPad session (no parent
  sign-in) are the two next refinements — see `docs/PROGRESS.md`.
   ```