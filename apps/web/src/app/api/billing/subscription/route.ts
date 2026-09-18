import { NextResponse } from "next/server";
import { resolveFamilyId, verifyIdToken } from "@/lib/billing/firebase-admin";
import { isPayMongoConfigured, retrieveSubscription } from "@/lib/billing/paymongo";
import {
  getActiveSubscriptionForFamily,
  hasActivePremiumSubscription,
} from "@/lib/billing/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }
  try {
    const user = await verifyIdToken(match[1]!);
    const { familyId, email } = await resolveFamilyId(user.uid);
    if (!familyId) {
      return NextResponse.json({ plan: "free", status: "none" });
    }

    const premium = await hasActivePremiumSubscription(familyId, email);
    const sub = await getActiveSubscriptionForFamily(familyId);

    let live: Awaited<ReturnType<typeof retrieveSubscription>> | null = null;
    if (sub?.providerSubscriptionId && isPayMongoConfigured()) {
      try {
        live = await retrieveSubscription(sub.providerSubscriptionId);
      } catch {
        live = null;
      }
    }

    return NextResponse.json({
      premium,
      plan: premium ? "plus" : "free",
      status: sub?.status ?? (premium ? "active" : "none"),
      amount: sub?.amount ?? null,
      currency: sub?.currency ?? null,
      currentPeriodEnd: sub?.currentPeriodEnd ?? null,
      cancelAtPeriodEnd: sub?.cancelAtPeriodEnd ?? false,
      providerSubscriptionId: sub?.providerSubscriptionId ?? null,
      liveStatus: live?.attributes.status ?? null,
    });
  } catch (e) {
    console.error("[billing/subscription]", e instanceof Error ? e.message : e);
    return NextResponse.json({ error: "Could not load subscription." }, { status: 500 });
  }
}
