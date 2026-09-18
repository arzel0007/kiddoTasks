import { NextResponse } from "next/server";
import { resolveFamilyId, verifyIdToken } from "@/lib/billing/firebase-admin";
import {
  createCheckoutSession,
  createCustomer,
  createPlan,
  createSubscription,
  isPayMongoConfigured,
} from "@/lib/billing/paymongo";
import { resolvePlan } from "@/lib/billing/plans";
import {
  getOrCreatePlanId,
  getPayMongoCustomer,
  savePayMongoCustomer,
  upsertSubscription,
} from "@/lib/billing/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function baseUrl(req: Request): string {
  const env = process.env.NEXT_PUBLIC_APP_URL;
  if (env) return env.replace(/\/$/, "");
  const url = new URL(req.url);
  return `${url.protocol}//${url.host}`;
}

async function requireAuth(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  try {
    return await verifyIdToken(match[1]!);
  } catch {
    return null;
  }
}

/**
 * POST /api/billing/checkout
 * Body: { plan: "premium_monthly" }
 * Creates PayMongo customer + subscription + hosted checkout for first payment.
 */
export async function POST(req: Request) {
  try {
    if (!isPayMongoConfigured()) {
      return NextResponse.json(
        {
          error:
            "PayMongo isn’t configured. Add PAYMONGO_SECRET_KEY to apps/web/.env.local.",
        },
        { status: 501 }
      );
    }

    const user = await requireAuth(req);
    if (!user) {
      return NextResponse.json({ error: "Sign in required." }, { status: 401 });
    }

    const body = (await req.json().catch(() => ({}))) as { plan?: string };
    const plan = resolvePlan(body.plan ?? "premium_monthly");
    if (!plan) {
      return NextResponse.json({ error: "Unknown plan." }, { status: 400 });
    }

    const { familyId, email, displayName } = await resolveFamilyId(user.uid);
    if (!familyId) {
      return NextResponse.json(
        { error: "No family linked to this account." },
        { status: 400 }
      );
    }
    if (!email) {
      return NextResponse.json(
        { error: "Account email is required for billing." },
        { status: 400 }
      );
    }

    // 1) Customer
    let customerId = (await getPayMongoCustomer(user.uid))?.customerId;
    if (!customerId) {
      const parts = (displayName || "Parent").trim().split(/\s+/);
      const customer = await createCustomer({
        email,
        firstName: parts[0] || "Parent",
        lastName: parts.slice(1).join(" ") || "KiddoTasks",
      });
      customerId = customer.id;
      await savePayMongoCustomer(user.uid, customerId, familyId, email);
    }

    // 2) PayMongo plan (cached in Firestore; server decides amount)
    const paymongoPlanId = await getOrCreatePlanId(plan.id, async () => {
      const created = await createPlan(plan);
      return created.id;
    });

    // 3) Subscription (incomplete until first payment)
    const sub = await createSubscription({
      customerId,
      planId: paymongoPlanId,
    });

    // 4) Hosted checkout for first cycle (cards, GCash, Maya)
    const origin = baseUrl(req);
    const session = await createCheckoutSession({
      amount: plan.amount,
      currency: plan.currency,
      description: `${plan.name} — first month`,
      referenceNumber: sub.id,
      successUrl: `${origin}/parent/billing/success?sub=${encodeURIComponent(sub.id)}`,
      cancelUrl: `${origin}/parent/billing/cancelled`,
    });

    await upsertSubscription({
      familyId,
      parentUid: user.uid,
      provider: "paymongo",
      providerCustomerId: customerId,
      providerSubscriptionId: sub.id,
      checkoutSessionId: session.id,
      planId: plan.id,
      planName: plan.name,
      amount: plan.amount,
      currency: plan.currency,
      status: "incomplete",
      cancelAtPeriodEnd: false,
    });

    const url = session.attributes.checkout_url;
    if (!url) {
      return NextResponse.json(
        { error: "PayMongo did not return a checkout URL." },
        { status: 502 }
      );
    }

    return NextResponse.json({
      url,
      subscriptionId: sub.id,
      plan: plan.id,
      amount: plan.amount,
      currency: plan.currency,
      display: plan.display,
    });
  } catch (e) {
    console.error("[billing/checkout]", e instanceof Error ? e.message : e);
    return NextResponse.json(
      {
        error:
          e instanceof Error
            ? e.message
            : "Could not start checkout. Try again.",
      },
      { status: 500 }
    );
  }
}
