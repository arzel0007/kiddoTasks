import type { WishlistOccasion, WishlistStatus } from "./types";

/** Occasions for wishlist items (aligned with Cloud Functions WISHLIST_OCCASIONS). */
export const WISHLIST_OCCASIONS: { id: WishlistOccasion; label: string }[] = [
  { id: "BIRTHDAY", label: "Birthday" },
  { id: "CHRISTMAS", label: "Christmas" },
  { id: "GRADUATION", label: "Graduation" },
  { id: "SCHOOL", label: "School" },
  { id: "SPECIAL", label: "Special" },
  { id: "JUST_BECAUSE", label: "Just because" },
  { id: "OTHER", label: "Other" },
];

export const WISHLIST_STATUS_LABELS: Record<WishlistStatus, string> = {
  PENDING: "Waiting",
  APPROVED: "Approved",
  REJECTED: "Rejected",
  RECEIVED: "Received",
};

/** Status tags — compact solid chips, smaller than card titles. */
const TAG_BASE =
  "inline-flex items-center rounded-pill px-2 py-0 text-[10px] font-semibold uppercase tracking-wide leading-none text-white";

export const WISHLIST_STATUS_BADGE: Record<WishlistStatus, string> = {
  PENDING: `${TAG_BASE} bg-[#3978A8]`,
  APPROVED: `${TAG_BASE} bg-[#3F8B70]`,
  REJECTED: `${TAG_BASE} bg-[#D97868]`,
  RECEIVED: `${TAG_BASE} bg-[#8B99A8]`,
};

/** Safe tag class — unknown status falls back to Pending styling. */
export function wishlistStatusBadgeClass(status: string | null | undefined): string {
  if (status && status in WISHLIST_STATUS_BADGE) {
    return WISHLIST_STATUS_BADGE[status as WishlistStatus];
  }
  return WISHLIST_STATUS_BADGE.PENDING;
}

export function occasionLabel(id: string | null | undefined): string {
  if (!id) return "";
  return WISHLIST_OCCASIONS.find((o) => o.id === id)?.label ?? String(id);
}

/** enableWishlist === true only when explicitly enabled (missing = false). */
export function isWishlistEnabled(
  family: { settings?: { enableWishlist?: boolean } } | null | undefined
): boolean {
  return family?.settings?.enableWishlist === true;
}

/** Format ISO date (or Firestore timestamp-like) for cards. */
export function formatWishlistDate(value?: string | null): string {
  if (!value) return "";
  try {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch {
    return "";
  }
}

/** Parent/parent-station path uses Firebase Auth; kid path needs kidsAccessToken. */
export function isReceivableStatus(status: WishlistStatus): boolean {
  return status !== "RECEIVED";
}
