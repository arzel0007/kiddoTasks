import { NextRequest, NextResponse } from "next/server";
import { verifyIdToken, resolveFamilyId } from "@/lib/billing/firebase-admin";

export interface AuthedRequest {
  uid: string;
  email: string | null;
  familyId: string;
}

export async function requireAuth(
  req: NextRequest
): Promise<{ ok: true; auth: AuthedRequest } | { ok: false; response: NextResponse }> {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return { ok: false, response: NextResponse.json({ error: "Sign in required." }, { status: 401 }) };
  }
  try {
    const user = await verifyIdToken(match[1]);
    const { familyId, email } = await resolveFamilyId(user.uid);
    if (!familyId) {
      return { ok: false, response: NextResponse.json({ error: "No family." }, { status: 400 }) };
    }
    return { ok: true, auth: { uid: user.uid, email, familyId } };
  } catch {
    return { ok: false, response: NextResponse.json({ error: "Invalid token." }, { status: 401 }) };
  }
}

/** Ensure the resource being touched belongs to the caller's family. */
export function requireFamilyMatch(
  auth: AuthedRequest,
  resourceFamilyId: string | null | undefined
): NextResponse | null {
  if (!resourceFamilyId || resourceFamilyId !== auth.familyId) {
    return NextResponse.json({ error: "Not allowed for this family." }, { status: 403 });
  }
  return null;
}