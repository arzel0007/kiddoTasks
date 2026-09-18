import { NextResponse } from "next/server";
import {
  isPayMongoConfigured,
  mapSubscriptionStatus,
  retrieveSubscription,
  verifyPayMongoSignature,
} from "@/lib/billing/paymongo";
import { resolvePlan } from "@/lib/billing/plans";
import {
  claimWebhookEvent,
  getSubscriptionByCheckoutSession,
  getSubscriptionByPayMongoId,
  markWebhookProcessed,
  recordPayment,
  setFamilyPlan,
  upsertSubscription,
} from "@/lib/billing/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type PayMongoEvent = {
  data?: {
    id?: string;
    type?: string;
    attributes?: Record<string, unknown>;
  };
};

/**
 * POST /api/webhooks/paymongo
 * Verify signature, process idempotently, never trust frontend redirects.
 */
export async function POST(req: Request) {
  const secret = process.env.PAYMONGO_WEBHOOK_SECRET;
  if (!isPayMongoConfigured() || !secret) {
    return NextResponse.json({ received: true }, { status: 200 });
  }

  const raw = await req.text();
  const sig = req.headers.get("paymongo-signature");
  if (!verifyPayMongoSignature(raw, sig, secret)) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  let payload: PayMongoEvent;
  try {
    payload = JSON.parse(raw) as PayMongoEvent;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const eventId = payload.data?.id;
  const eventType = payload.data?.type ?? "";
  if (!eventId) {
    return NextResponse.json({ received: true }, { status: 200 });
  }

  // Ignore unrecognized types (ack 200 so PayMongo does not retry forever)
  const handled = [
    "checkout_session.payment.paid",
    "checkout_session.payment.failed",
    "payment.paid",
    "payment.failed",
    "subscription.activated",
    "subscription.cancelled",
    "subscription.unpaid",
    "subscription.past_due",
  ];
  if (!handled.includes(eventType)) {
    return NextResponse.json({ received: true, skipped: true }, { status: 200 });
  }

  const claimed = await claimWebhookEvent(eventId, eventType);
  if (!claimed) {
    return NextResponse.json({ received: true, duplicate: true }, { status: 200 });
  }

  try {
    await handleEvent(eventType, payload);
    await markWebhookProcessed(eventId, true);
  } catch (e) {
    console.error("[webhook/paymongo]", eventType, e instanceof Error ? e.message : e);
    await markWebhookProcessed(eventId, false);
    // 200 to avoid infinite retries for permanent errors; PayMongo still logs
    return NextResponse.json({ received: true, error: true }, { status: 200 });
  }

  return NextResponse.json({ received: true }, { status: 200 });
}

async function handleEvent(eventType: string, payload: PayMongoEvent) {
  const attrs = payload.data?.attributes ?? {};

  if (eventType === "checkout_session.payment.paid") {
    const sessionId = String(payload.data?.id ?? "");
    const reference =
      (attrs.reference_number as string) ||
      ((attrs as { reference_number?: string }).reference_number ?? "");
    const paymentId =
      (attrs.payment_intent as { id?: string } | undefined)?.id ||
      `cs_${sessionId}`;

    let sub = await getSubscriptionByCheckoutSession(sessionId);
    if (!sub && reference.startsWith("sub_")) {
      sub = await getSubscriptionByPayMongoId(reference);
    }
    if (!sub && reference) {
      sub = await getSubscriptionByPayMongoId(reference);
    }
    if (!sub) {
      console.warn("[webhook] no subscription for checkout", sessionId, reference);
      return;
    }

    const amount =
      typeof attrs.amount === "number"
        ? attrs.amount
        : (attrs.total_amount as number) ?? sub.amount;

    await recordPayment({
      subscriptionId: sub.providerSubscriptionId,
      familyId: sub.familyId,
      parentUid: sub.parentUid,
      provider: "paymongo",
      providerPaymentId: paymentId,
      providerCheckoutSessionId: sessionId,
      amount: amount ?? sub.amount,
      currency: (attrs.currency as string) ?? sub.currency,
      status: "paid",
      paidAt: new Date().toISOString(),
    });

    // Sync from PayMongo subscription if present (period end, status)
    let status = "active";
    let periodEnd: string | null = null;
    try {
      const pmSub = await retrieveSubscription(sub.providerSubscriptionId);
      status = mapSubscriptionStatus(pmSub.attributes.status);
      const next = pmSub.attributes.next_billing_schedule;
      if (next) {
        periodEnd = typeof next === "number"
          ? new Date(next * 1000).toISOString()
          : new Date(next).toISOString();
      }
    } catch {
      // First payment confirmed via checkout; treat as active for 30 days
      periodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    }

    const now = new Date().toISOString();
    await upsertSubscription({
      familyId: sub.familyId,
      parentUid: sub.parentUid,
      provider: "paymongo",
      providerCustomerId: sub.providerCustomerId,
      providerSubscriptionId: sub.providerSubscriptionId,
      checkoutSessionId: sub.checkoutSessionId ?? null,
      planId: sub.planId,
      planName: sub.planName,
      amount: sub.amount,
      currency: sub.currency,
      status: status === "incomplete" ? "active" : status,
      currentPeriodStart: sub.currentPeriodStart ?? now,
      currentPeriodEnd: periodEnd ?? sub.currentPeriodEnd,
      cancelAtPeriodEnd: sub.cancelAtPeriodEnd ?? false,
    });

    if (status === "active" || status === "incomplete") {
      await setFamilyPlan(sub.familyId, "plus");
    }
    return;
  }

  if (eventType === "payment.paid") {
    const paymentId = String(payload.data?.id ?? "");
    const subId =
      (attrs.subscription_id as string) ||
      ((attrs as { subscription?: { id?: string } }).subscription?.id ?? "");
    if (!subId) return;
    const sub = await getSubscriptionByPayMongoId(subId);
    if (!sub) return;
    await recordPayment({
      subscriptionId: sub.providerSubscriptionId,
      familyId: sub.familyId,
      parentUid: sub.parentUid,
      provider: "paymongo",
      providerPaymentId: paymentId,
      amount: (attrs.amount as number) ?? sub.amount,
      currency: (attrs.currency as string) ?? sub.currency,
      status: "paid",
      paidAt: new Date().toISOString(),
    });
    const plan = resolvePlan(sub.planId);
    await setFamilyPlan(sub.familyId, "plus");
    void plan;
    return;
  }

  if (
    eventType === "subscription.activated" ||
    eventType === "subscription.cancelled" ||
    eventType === "subscription.unpaid" ||
    eventType === "subscription.past_due"
  ) {
    const subId = String(payload.data?.id ?? "");
    if (!subId) return;
    const sub = await getSubscriptionByPayMongoId(subId);
    if (!sub) return;
    const pmStatus = String(attrs.status ?? "");
    const mapped = mapSubscriptionStatus(pmStatus || eventType.replace("subscription.", ""));
    const next = attrs.next_billing_schedule as string | number | undefined;
    const periodEnd = next
      ? typeof next === "number"
        ? new Date(next * 1000).toISOString()
        : new Date(next).toISOString()
      : sub.currentPeriodEnd;

    await upsertSubscription({
      familyId: sub.familyId,
      parentUid: sub.parentUid,
      provider: "paymongo",
      providerCustomerId: sub.providerCustomerId,
      providerSubscriptionId: sub.providerSubscriptionId,
      checkoutSessionId: sub.checkoutSessionId ?? null,
      planId: sub.planId,
      planName: sub.planName,
      amount: sub.amount,
      currency: sub.currency,
      status: mapped,
      currentPeriodStart: sub.currentPeriodStart ?? null,
      currentPeriodEnd: periodEnd ?? null,
      cancelAtPeriodEnd: sub.cancelAtPeriodEnd ?? false,
      canceledAt: mapped === "canceled" ? new Date().toISOString() : sub.canceledAt ?? null,
    });

    if (mapped === "active") {
      await setFamilyPlan(sub.familyId, "plus");
    } else if (mapped === "canceled" || mapped === "unpaid") {
      await setFamilyPlan(sub.familyId, "free");
    }
  }
}
