# Kiddotasks Web

Web client for the same Firebase project as the iOS app (`kiddotasks-app`).

## Setup

```bash
cd apps/web
cp .env.example .env.local
# Fill NEXT_PUBLIC_FIREBASE_* from Firebase Console → Project settings → Web app

npm install
npm run dev
```

Open http://localhost:3000

## Routes

| Path | Purpose |
|---|---|
| `/` | Sign in / Create / Join / Kids PIN |
| `/pricing` | Public pricing |
| `/parent/*` | Parent Center (auth) |
| `/kids` | Kids Station (PIN session) |
| `/parent/billing` | Plan + Stripe stub |

## Monetization (next)

1. Create Stripe products/prices (Plus monthly/annual)
2. Set `STRIPE_SECRET_KEY`, price IDs in `.env.local`
3. Implement Checkout in `src/app/api/stripe/checkout/route.ts`
4. Implement webhook → write `families/{id}.entitlements`

## Same backend as iOS

- Callables: `bootstrapFamily`, `joinFamilyWithCode`, `openKidsSession`, `pushFamilySnapshot`
- Firestore collections: families, parents, children, tasks, …
- Storage: `families/{id}/…`

No mini-games on web (by design).
