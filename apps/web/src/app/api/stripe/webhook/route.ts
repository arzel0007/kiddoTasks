import { NextResponse } from "next/server";

/**
 * Stripe webhook stub — not implemented. Return 501 so Stripe cannot silently
 * ack real events against a handler that writes nothing.
 */
export async function POST(req: Request) {
  void req;
  return NextResponse.json(
    { error: "Stripe webhook is not implemented." },
    { status: 501 }
  );
}
