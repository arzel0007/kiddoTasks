import { NextResponse } from "next/server";
import { resolveFamilyId, verifyIdToken } from "@/lib/billing/firebase-admin";
import { cancelSubscription, isPayMongoConfigured } from "@/lib/billing/paymongo";
import {
  getActiveSubscriptionForFamily,
  setFamilyPlan,
  upsertSubscription,
} from "@/lib/billing/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/billing/cancel
 * Cancels the PayMongo subscription. Access ends per provider rules
 * (PayMongo cancel is immediate; we still mark canceled in Firestore).
 */
export async function POST(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }
  try {
    const user = await verifyIdToken(match[1]!);
    const { familyId, email } = await resolveFamilyId(user.uid);
    if (!familyId) {
      return NextResponse.json({ error: "No family." }, { status: 400 });
    }
    const { isOwnerEmail } = await import("@/lib/entitlements");
    if (isOwnerEmail(email)) {
      return NextResponse.json(
        { error: "Founder account is always Premium." },
        { status: 400 }
      );
    }

    const sub = await getActiveSubscriptionForFamily(familyId);
    if (!sub) {
      return NextResponse.json({ error: "No active subscription." }, { status: 404 });
    }

    if (isPayMongoConfigured() && sub.providerSubscriptionId) {
      try {
        await cancelSubscription(sub.providerSubscriptionId);
      } catch (e) {
        console.error("[billing/cancel] PayMongo", e instanceof Error ? e.message : e);
      }
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
      status: "canceled",
      currentPeriodStart: sub.currentPeriodStart ?? null,
      currentPeriodEnd: sub.currentPeriodEnd ?? null,
      cancelAtPeriodEnd: false,
      canceledAt: now,
    });
    await setFamilyPlan(familyId, "free");

    return NextResponse.json({ ok: true, status: "canceled" });
  } catch (e) {
    console.error("[billing/cancel]", e instanceof Error ? e.message : e);
    return NextResponse.json({ error: "Could not cancel subscription." }, { status: 500 });
  }
}
