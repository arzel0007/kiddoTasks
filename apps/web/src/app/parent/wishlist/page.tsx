"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { Modal } from "@/components/ui/modal";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import { ChildAvatar } from "@/lib/ui";
import {
  formatWishlistDate,
  occasionLabel,
  wishlistStatusBadgeClass,
  WISHLIST_STATUS_LABELS,
} from "@/lib/wishlist";
import type { WishlistItem } from "@/lib/types";

type ReviewTarget = {
  item: WishlistItem;
  decision: "APPROVED" | "REJECTED";
};

export default function ParentWishlistPage() {
  const {
    family,
    children,
    wishlistItems,
    wishlistEnabled,
    loading,
    reviewWishlistItem,
  } = useFamilyStore();
  const [childFilter, setChildFilter] = useState<string>("all");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [review, setReview] = useState<ReviewTarget | null>(null);
  const [responseMsg, setResponseMsg] = useState("");
  const [savingReview, setSavingReview] = useState(false);

  const visible = useMemo(
    () => wishlistItems.filter((w) => w.status !== "RECEIVED"),
    [wishlistItems]
  );

  const filtered = useMemo(() => {
    if (childFilter === "all") return visible;
    return visible.filter((w) => w.childId === childFilter);
  }, [visible, childFilter]);

  const pending = filtered.filter((w) => w.status === "PENDING");
  const approved = filtered.filter((w) => w.status === "APPROVED");
  const rejected = filtered.filter((w) => w.status === "REJECTED");

  const pendingByChild = useMemo(() => {
    const map = new Map<string, number>();
    for (const w of visible) {
      if (w.status === "PENDING") {
        map.set(w.childId, (map.get(w.childId) ?? 0) + 1);
      }
    }
    return map;
  }, [visible]);

  const totalPending = visible.filter((w) => w.status === "PENDING").length;

  const childOf = (childId: string) => children.find((c) => c.id === childId) ?? null;

  function openReview(item: WishlistItem, decision: "APPROVED" | "REJECTED") {
    setReview({ item, decision });
    setResponseMsg(item.parentResponse ?? "");
  }

  async function submitReview() {
    if (!review) return;
    setBusyId(review.item.id);
    setSavingReview(true);
    try {
      await reviewWishlistItem({
        itemId: review.item.id,
        decision: review.decision,
        parentResponse: responseMsg.trim() || null,
        version: review.item.version,
      });
      toast.success(
        review.decision === "APPROVED"
          ? `Approved “${review.item.title}”.`
          : `Rejected “${review.item.title}”.`
      );
      setReview(null);
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t save review."));
    } finally {
      setBusyId(null);
      setSavingReview(false);
    }
  }

  function renderCard(item: WishlistItem, opts: { showStatus?: boolean } = {}) {
    const child = childOf(item.childId);
    const occasion = occasionLabel(item.occasion);
    return (
      <li key={item.id} className="rounded-card border border-border p-3">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              {child ? (
                <span className="inline-flex items-center gap-1.5">
                  <ChildAvatar
                    emoji={child.avatar?.emoji}
                    colorHex={child.avatar?.colorHex}
                    photoURL={child.photoURL}
                    photoData={child.photoData}
                    size={20}
                    name={child.name}
                  />
                  <span className="text-xs font-semibold text-ink-secondary">
                    {child.name}
                  </span>
                </span>
              ) : null}
              {opts.showStatus ? (
                <span className={wishlistStatusBadgeClass(item.status)}>
                  {WISHLIST_STATUS_LABELS[item.status] ?? item.status}
                </span>
              ) : null}
              {occasion ? (
                <span className="text-xs text-ink-tertiary">{occasion}</span>
              ) : null}
            </div>
            <p className="mt-1 truncate font-semibold">{item.title}</p>
            {item.message ? (
              <p className="text-sm text-ink-secondary line-clamp-2">{item.message}</p>
            ) : null}
            {item.parentResponse ? (
              <div className="mt-2 rounded-lg border-l-2 border-primary bg-primary-light/40 px-2.5 py-1.5">
                <p className="text-[10px] font-semibold uppercase tracking-wide text-primary">
                  You replied
                </p>
                <p className="text-sm italic text-ink">{item.parentResponse}</p>
              </div>
            ) : null}
            <p className="mt-1.5 text-[11px] text-ink-tertiary">
              {formatWishlistDate(item.createdAt) || formatWishlistDate(item.updatedAt)}
            </p>
          </div>
          {item.status === "PENDING" ? (
            <div className="flex shrink-0 flex-wrap gap-1.5">
              <button
                type="button"
                className="btn-secondary btn-compact"
                disabled={busyId === item.id}
                onClick={() => openReview(item, "APPROVED")}
              >
                Approve
              </button>
              <button
                type="button"
                className="btn-secondary btn-compact !text-attention"
                disabled={busyId === item.id}
                onClick={() => openReview(item, "REJECTED")}
              >
                Reject
              </button>
            </div>
          ) : null}
        </div>
      </li>
    );
  }

  function Section({
    title,
    count,
    items,
    empty,
    emptyAction,
    showStatus,
  }: {
    title: string;
    count: number;
    items: WishlistItem[];
    empty: string;
    emptyAction?: React.ReactNode;
    showStatus?: boolean;
  }) {
    return (
      <div className="card">
        <div className="mb-2 flex items-center gap-2">
          <h2 className="font-bold">{title}</h2>
          <span
            className={`rounded-pill px-2 py-0.5 text-[10px] font-semibold ${
              count > 0 ? "bg-primary-light text-primary" : "bg-surface text-ink-tertiary"
            }`}
          >
            {count}
          </span>
        </div>
        {items.length === 0 ? (
          <div className="py-1">
            <p className="text-sm text-ink-secondary">{empty}</p>
            {emptyAction ? <div className="mt-2">{emptyAction}</div> : null}
          </div>
        ) : (
          <ul className="space-y-2.5">{items.map((item) => renderCard(item, { showStatus }))}</ul>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {!wishlistEnabled ? (
        <div className="card border-border bg-surface">
          <p className="font-semibold">Wishlist is off for this family</p>
          <p className="mt-1 text-sm text-ink-secondary">
            Kids can’t add items until you turn it on in Family settings. You can still
            manage existing requests here.
          </p>
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2 text-sm text-ink-secondary">
        <span className="font-semibold text-ink">
          {totalPending} pending
        </span>
        <span aria-hidden>·</span>
        <span>{approved.length} approved</span>
        <span aria-hidden>·</span>
        <span>{rejected.length} rejected</span>
        {family?.name ? (
          <>
            <span aria-hidden>·</span>
            <span className="truncate">{family.name}</span>
          </>
        ) : null}
      </div>

      <div className="card !py-3">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-ink-tertiary">Kids</span>
          <button
            type="button"
            className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
              childFilter === "all"
                ? "bg-primary text-white"
                : "bg-surface text-ink-secondary"
            }`}
            onClick={() => setChildFilter("all")}
          >
            All
            {totalPending > 0 ? (
              <span className="ml-1.5 rounded-pill bg-white/20 px-1.5 text-[10px]">
                {totalPending}
              </span>
            ) : null}
          </button>
          {children.map((c) => {
            const pendingCount = pendingByChild.get(c.id) ?? 0;
            return (
              <button
                key={c.id}
                type="button"
                className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${
                  childFilter === c.id
                    ? "bg-primary text-white"
                    : "bg-surface text-ink-secondary"
                }`}
                onClick={() => setChildFilter(c.id)}
              >
                <ChildAvatar
                  emoji={c.avatar?.emoji}
                  colorHex={c.avatar?.colorHex}
                  photoURL={c.photoURL}
                  photoData={c.photoData}
                  size={18}
                  name={c.name}
                />
                {c.name}
                {pendingCount > 0 ? (
                  <span className="rounded-pill bg-attention px-1.5 text-[10px] font-bold text-white">
                    {pendingCount}
                  </span>
                ) : null}
              </button>
            );
          })}
        </div>
      </div>

      {loading ? (
        <div className="card">
          <p className="text-sm text-ink-secondary">Loading wishlist…</p>
        </div>
      ) : (
        <>
          <Section
            title="Pending"
            count={pending.length}
            items={pending}
            empty="No waiting requests."
            emptyAction={
              <Link href="/kids" className="btn-secondary btn-compact inline-flex w-auto">
                Open Kids Station
              </Link>
            }
          />
          {approved.length > 0 || childFilter !== "all" ? (
            <Section
              title="Approved"
              count={approved.length}
              items={approved}
              empty="Nothing approved yet."
            />
          ) : null}
          {rejected.length > 0 || childFilter !== "all" ? (
            <Section
              title="Rejected"
              count={rejected.length}
              items={rejected}
              empty="No rejected requests."
            />
          ) : null}
        </>
      )}

      <Modal
        open={review !== null}
        title={
          review?.decision === "APPROVED" ? "Approve wishlist item?" : "Reject wishlist item?"
        }
        description={
          review
            ? `“${review.item.title}” — this never changes stars or points.`
            : undefined
        }
        onClose={() => {
          if (!savingReview) setReview(null);
        }}
      >
        <div className="space-y-3 text-left">
          <div>
            <label className="field-label" htmlFor="wishlist-parent-response">
              Message to {childOf(review?.item.childId ?? "")?.name ?? "your child"} (optional)
            </label>
            <textarea
              id="wishlist-parent-response"
              className="field-input min-h-[88px]"
              maxLength={500}
              placeholder="Maybe for your birthday…"
              value={responseMsg}
              onChange={(e) => setResponseMsg(e.target.value)}
            />
          </div>
          <button
            type="button"
            className="btn-primary"
            disabled={savingReview}
            onClick={() => void submitReview()}
          >
            {savingReview
              ? "Saving…"
              : review?.decision === "APPROVED"
                ? "Approve"
                : "Reject"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            disabled={savingReview}
            onClick={() => setReview(null)}
          >
            Cancel
          </button>
        </div>
      </Modal>
    </div>
  );
}
