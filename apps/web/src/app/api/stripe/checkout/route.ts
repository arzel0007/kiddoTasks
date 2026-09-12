import { NextResponse } from "next/server";

/**
 * Stripe Checkout stub — enable by setting STRIPE_* env vars and
 * implementing session creation with the stripe SDK on the server.
 */
export async function POST(req: Request) {
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    return NextResponse.json(
      {
        error:
          "Stripe isn’t configured. Add STRIPE_SECRET_KEY + price IDs to apps/web/.env.local.",
      },
      { status: 501 }
    );
  }
  // TODO: create Checkout session for authenticated uid + plan
  void req;
  return NextResponse.json(
    { error: "Checkout session not implemented yet." },
    { status: 501 }
  );
}
