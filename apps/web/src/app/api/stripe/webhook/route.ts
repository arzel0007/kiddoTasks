import { NextResponse } from "next/server";

/**
 * Stripe webhook stub — verify signature and write entitlements to Firestore.
 */
export async function POST(req: Request) {
  void req;
  return NextResponse.json(
    { received: true, note: "Implement signature verify + entitlement write." },
    { status: 200 }
  );
}
