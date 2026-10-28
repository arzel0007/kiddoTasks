import { NextResponse } from "next/server";
import { requireAuth, requireFamilyMatch } from "@/lib/api-auth";
import { adminDb, adminAuth } from "@/lib/billing/firebase-admin";
import { v4 as uuidv4 } from "uuid";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** POST /api/auth/bootstrap — create a family for a newly signed-up parent.
 * Returns a 6-digit Kids Station PIN.
 */
export async function POST(req: Request) {
  const auth = await requireAuth(req as any);
  if (!auth.ok) return auth.response;

  // Check if family already exists for this user
  const existing = await adminDb()
    .collection("families")
    .where("members", "array-contains", auth.auth.uid)
    .limit(1)
    .get();
  if (!existing.empty) {
    const fam = existing.docs[0].data()!;
    return NextResponse.json({ familyId: fam.id, kidsPin: fam.settings?.kidsStationPIN });
  }

  const familyId = uuidv4();
  const kidsPin = Math.floor(100000 + Math.random() * 900000).toString();
  const now = new Date().toISOString();

  const family = {
    id: familyId,
    name: "My Family",
    members: [auth.auth.uid],
    familyCode: Array.from({ length: 6 }, () => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[Math.floor(Math.random() * 30)]).join(""),
    settings: {
      pointDisplaySymbol: "⭐",
      enableNotifications: true,
      celebrationAnimationsEnabled: true,
      requireApprovalByDefault: true,
      weekStartsOn: 1,
      kidsStationPIN: kidsPin,
      enableMiniGames: true,
      basketballMaxMinutes: 0,
      allowanceMode: "STARS_ONLY",
      flatDailyAmount: 1.0,
      weekBonusTitle: "Full week!",
      plan: "free",
      enableWishlist: false,
    },
    createdAt: now,
    updatedAt: now,
  };

  await adminDb().collection("families").doc(familyId).set(family);

  // Also create a parents/{uid} doc so resolveFamilyId works
  await adminDb().collection("parents").doc(auth.auth.uid).set({
    uid: auth.auth.uid,
    familyId,
    email: auth.auth.email,
    displayName: auth.auth.email?.split("@")[0] || "Parent",
    createdAt: now,
  });

  // Set custom claim so client can identify as parent
  try {
    await adminAuth().setCustomUserClaims(auth.auth.uid, { role: "parent", familyId });
  } catch {
    // non-fatal
  }

  return NextResponse.json({ familyId, kidsPin }, { status: 201 });
}