# KiddoTasks Payments (PayMongo)

Premium is **₱199 PHP / month**, recurring. Cards, GCash, and Maya via PayMongo.

## Flow

```
User → Billing page → POST /api/billing/checkout (Firebase ID token)
  → PayMongo Customer + Plan + Subscription + Hosted Checkout
  → Redirect to PayMongo checkout_url
  → User pays
  → PayMongo webhook → POST /api/webhooks/paymongo
  → paymentTransactions + subscriptions + families.settings.plan = "plus"
  → Success page polls GET /api/billing/subscription until premium
```

**Premium is never set from a browser redirect.** Only the webhook (verified signature + idempotent event id) activates the plan.

## Environment (`apps/web/.env.local`)

| Variable | Purpose |
|----------|---------|
| `PAYMONGO_SECRET_KEY` | Server-only (`sk_test_…` / `sk_live_…`) |
| `PAYMONGO_PUBLIC_KEY` | Optional client use (`pk_test_…`) |
| `PAYMONGO_WEBHOOK_SECRET` | Webhook HMAC secret |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Admin SDK (token verify + Firestore) |
| `NEXT_PUBLIC_APP_URL` | Success/cancel redirect base |

Never commit `.env.local`. Use test keys in development.

## Plan catalog (server)

`premium_monthly` = **19900** centavos (₱199.00), PHP, interval `month`.  
Browser sends only `{ plan: "premium_monthly" }`. Amount is never trusted from the client.

## Firestore collections

- `subscriptions/{paymongoSubscriptionId}` — status, period, customer  
- `paymentTransactions/{paymentId}` — audit trail (idempotent by id)  
- `webhookEvents/{eventId}` — dedupe  
- `paymongoCustomers/{parentUid}` — customer reuse  
- `billingPlans/premium_monthly` — cached PayMongo plan id  
- `families/{id}.settings.plan` — `plus` when active (client display)

## API

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/billing/checkout` | Firebase Bearer token |
| GET | `/api/billing/subscription` | Firebase Bearer token |
| POST | `/api/billing/cancel` | Firebase Bearer token |
| POST | `/api/webhooks/paymongo` | PayMongo signature |

## Webhook setup (PayMongo Dashboard)

1. Settings → Webhooks → Add endpoint  
2. URL: `https://<your-host>/api/webhooks/paymongo`  
3. Events: `checkout_session.payment.paid`, `checkout_session.payment.failed`, `payment.paid`, `payment.failed`, and subscription lifecycle events if available  
4. Copy the **webhook secret** into `PAYMONGO_WEBHOOK_SECRET`  
5. Use a **separate** webhook for live mode

## Test mode

1. PayMongo Dashboard → test keys  
2. Enable **Subscriptions** capability (contact PayMongo if needed)  
3. Complete a test checkout with test cards / sandbox GCash·Maya  
4. Confirm webhook delivery in the dashboard  
5. Success page should show **You're Premium!**

Test cards (from PayMongo docs): `4343434343434345` success; `4120000000000007` 3DS.

## Production

1. Complete PayMongo KYC / go-live  
2. Swap to live `sk_live_` / `pk_live_`  
3. Register a **live** webhook URL  
4. Never mix test and live keys  

## Failed payments

PayMongo retries renewals; status becomes `past_due` / `unpaid`. Family plan is set to `free` on cancel/unpaid webhooks. User can subscribe again from Billing.

## Cancellation

Billing → Cancel. Calls PayMongo `DELETE /v1/subscriptions/:id` and sets Firestore status `canceled` + plan `free`.

## Security

- Secret key only on the server  
- No card numbers / CVV stored  
- Webhook HMAC verify on raw body  
- Idempotent event processing  
- Firebase Admin verifies user before checkout  
- Server-side price resolution  

## Owner account

`xxarzelxx@gmail.com` is always Premium (no checkout).

## iOS

Web billing first. iOS can reuse `families.settings.plan` after webhook writes `plus`.
