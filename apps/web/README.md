# Kiddotasks Web

Same Firebase project as iOS (`kiddotasks-app`). Hosted on **Firebase Hosting** (Next.js web frameworks).

## Local dev

```bash
cd apps/web
cp .env.example .env.local
# Fill NEXT_PUBLIC_FIREBASE_* from Firebase Console → Project settings → Web app

npm install
npm run dev          # http://localhost:3000
npm run dev:clean    # kill ports, wipe .next, start on 3000
```

## Deploy to Firebase Hosting

From the **repo root** (not apps/web):

```bash
# once per machine
firebase experiments:enable webframeworks

cd ~/projects/GitHub/kiddoTasks
firebase deploy --only hosting
```

Firebase builds Next.js via the Hosting web-frameworks integration and deploys SSR + static assets to `kiddotasks-app.web.app` (or your custom domain).

### Required CLI login

```bash
firebase login
# .firebaserc already points at kiddotasks-app
```

### Environment variables (production)

Hosting **does not** read your laptop `.env.local`. After first deploy, set in the Firebase console **or** pass via Hosting config if your CLI supports it. For client-only Firebase JS config, bake env at build time:

1. Firebase Console → Project settings → Web app → copy config  
2. Put values in the **build environment** (CI secrets or export before `firebase deploy`):

```bash
export NEXT_PUBLIC_FIREBASE_API_KEY=...
export NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=kiddotasks-app.firebaseapp.com
export NEXT_PUBLIC_FIREBASE_PROJECT_ID=kiddotasks-app
export NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=kiddotasks-app.firebasestorage.app
export NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
export NEXT_PUBLIC_FIREBASE_APP_ID=...

firebase deploy --only hosting
```

> **Security:** Never commit API keys. Web API keys are public identifiers; real protection is Auth + Firestore/Storage rules. Still keep them out of git.

### What gets deployed

| Piece | Where |
|---|---|
| Next.js app | Hosting (SSR via web frameworks) |
| API routes (`/api/stripe/*`) | Hosting backend (us-central1) |
| Auth / Firestore / Storage | Same `kiddotasks-app` project |

### Verify after deploy

1. Open `https://kiddotasks-app.web.app`  
2. Sign in with the same parent email as iOS  
3. Today / Family / Kids Station should load the same data  

### Hosting emulator (optional)

```bash
firebase emulators:start
# web http://localhost:5000
```

## Routes

| Path | Purpose |
|---|---|
| `/` | Sign in · Create · Join · Kids PIN |
| `/pricing` | Tiers |
| `/parent/*` | Parent Center (auth) |
| `/kids` | Kids Station |
