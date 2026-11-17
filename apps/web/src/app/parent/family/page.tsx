"use client";

import { useEffect, useState } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { FREE_LIMITS } from "@/lib/entitlements";
import { ChildAvatar } from "@/lib/ui";
import { PageSkeleton } from "@/components/skeleton";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import { isWishlistEnabled } from "@/lib/wishlist";
import { computePlanDisplay } from "@/lib/billing/plan-status";
import { PlanStatusSummary } from "@/components/plan-status-summary";
import { Modal } from "@/components/ui/modal";
import { FamilyLoadError } from "@/components/family-load-error";
import {
  isWebPushSupported,
  subscribeWebPush,
  unsubscribeWebPush,
  webPushSubscriptionStatus,
} from "@/lib/web-push";
import {
  ABOUT_CLOSING,
  ABOUT_PARAGRAPHS,
  ABOUT_SIGNOFF,
  ABOUT_TAGLINE,
  ABOUT_TITLE,
} from "@/lib/about";

export default function FamilyPage() {
  const { family, children, loading, error, setEnableWishlist, parentEmail } = useFamilyStore();
  const ent = useEntitlements();
  const planDisplay = computePlanDisplay(ent, parentEmail);
  const [wishlistBusy, setWishlistBusy] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [pushStatus, setPushStatus] = useState<string>("…");
  const [pushBusy, setPushBusy] = useState(false);
  const wishlistOn = isWishlistEnabled(family);

  useEffect(() => {
    let alive = true;
    void (async () => {
      const s = await webPushSubscriptionStatus();
      if (alive) setPushStatus(s);
    })();
    return () => {
      alive = false;
    };
  }, []);

  async function toggleWebPush() {
    setPushBusy(true);
    try {
      if (pushStatus === "subscribed") {
        const res = await unsubscribeWebPush();
        if (!res.ok) toast.error(res.error || "Couldn’t turn off notifications.");
        else {
          toast.success("Browser notifications turned off.");
          setPushStatus("unsubscribed");
        }
      } else {
        const res = await subscribeWebPush();
        if (!res.ok) toast.error(res.error || "Couldn’t enable notifications.");
        else {
          toast.success("Browser notifications on — even when this tab is closed.");
          setPushStatus("subscribed");
        }
      }
    } finally {
      setPushBusy(false);
    }
  }

  async function toggleWishlist() {
    const next = !wishlistOn;
    setWishlistBusy(true);
    try {
      await setEnableWishlist(next);
      toast.success(next ? "Wishlist enabled for your family." : "Wishlist disabled.");
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t save wishlist setting."));
    } finally {
      setWishlistBusy(false);
    }
  }

  if (loading && !family) {
    return <PageSkeleton rows={2} />;
  }

  return (
    <div className="space-y-4">
      {!family ? <FamilyLoadError message={error} /> : null}
      <div className="card text-center">
        <div className="mx-auto mb-3 flex h-20 w-20 items-center justify-center overflow-hidden rounded-full bg-primary/10">
          {family?.photoURL || family?.photoData ? (
            <ChildAvatar
              photoURL={family.photoURL}
              photoData={family.photoData}
              emoji="👨‍👩‍👧"
              colorHex="#3978A8"
              size={80}
              name={family.name}
            />
          ) : (
            <span className="text-3xl">👨‍👩‍👧</span>
          )}
        </div>
        <h2 className="text-xl font-bold">{family?.name}</h2>
        <p className="mt-1 font-mono text-sm text-primary">
          {family?.familyCode ?? "------"}
        </p>
        <p className="mt-1 text-xs text-ink-secondary">
          Share this code with another parent
        </p>
      </div>

      <div className="card">
        <div className="mb-2 flex items-center justify-between">
          <h3 className="font-bold">Kids ({children.length})</h3>
          {!ent.isPlus && (
            <span className="text-xs text-ink-secondary">
              Free limit: {FREE_LIMITS.maxChildren}
            </span>
          )}
        </div>
        {children.length === 0 ? (
          <p className="text-sm text-ink-secondary">
            Add kids from the iOS Family tab — they show up here with photos.
          </p>
        ) : (
          <ul className="space-y-3">
            {children.map((c) => (
              <li key={c.id} className="flex items-center gap-3">
                <ChildAvatar
                  emoji={c.avatar.emoji}
                  colorHex={c.avatar.colorHex}
                  photoURL={c.photoURL}
                  photoData={c.photoData}
                  size={44}
                  name={c.name}
                />
                <div className="flex-1">
                  <p className="font-semibold">{c.name}</p>
                  <span className="rounded-pill bg-reward-light px-2.5 py-1 text-xs font-bold text-[#8a6420]">
                    ★ {c.activePoints}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        )}
        {!ent.isPlus && children.length >= FREE_LIMITS.maxChildren && (
          <p className="mt-3 rounded-xl bg-primary/10 p-3 text-sm">
            Upgrade to <strong>Plus</strong> for unlimited kids.{" "}
            <a href="/parent/billing" className="text-primary underline">
              See plans
            </a>
          </p>
        )}
      </div>

      <div className="card">
        <h3 className="mb-2 font-bold">Kids PIN</h3>
        <p className="font-mono text-2xl tracking-widest">
          {family?.settings?.kidsStationPIN ?? "••••"}
        </p>
        <p className="mt-1 text-xs text-ink-secondary">
          Used on the shared iPad / web Kids Station
        </p>
      </div>

      <div className="card">
        <div className="mb-2 flex items-center justify-between gap-3">
          <div>
            <h3 className="font-bold">Wishlist</h3>
            <p className="mt-1 text-xs text-ink-secondary">
              Gift ideas kids can request. Separate from stars and rewards.
            </p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={wishlistOn}
            disabled={wishlistBusy || !family}
            className={`relative h-8 w-14 shrink-0 rounded-full transition ${
              wishlistOn ? "bg-primary" : "bg-border"
            } ${wishlistBusy ? "opacity-60" : ""}`}
            onClick={() => void toggleWishlist()}
          >
            <span
              className={`absolute top-1 h-6 w-6 rounded-full bg-white shadow-card transition-all ${
                wishlistOn ? "left-7" : "left-1"
              }`}
            />
            <span className="sr-only">
              {wishlistOn ? "Disable wishlist" : "Enable wishlist"}
            </span>
          </button>
        </div>
        <p className="text-xs font-semibold text-ink-secondary">
          {wishlistOn ? "On — kids can add wishlist items" : "Off — kids cannot add items"}
        </p>
        <a href="/parent/wishlist" className="btn-secondary mt-3 inline-flex w-auto px-4">
          Open wishlist
        </a>
      </div>

      <PlanStatusSummary plan={planDisplay} compact />

      <div className="card">
        <h3 className="mb-2 font-bold">Browser notifications</h3>
        <p className="text-xs text-ink-secondary">
          Get alerts for mission approvals and reward requests — even when this
          tab is closed. Works on iPhone (Add to Home Screen), Android, and desktop.
        </p>
        {!isWebPushSupported() ? (
          <p className="mt-2 text-xs text-ink-tertiary">
            This browser doesn’t support push notifications.
          </p>
        ) : (
          <>
            <p className="mt-2 text-xs font-semibold text-ink-secondary">
              Status:{" "}
              {pushStatus === "subscribed"
                ? "On"
                : pushStatus === "denied"
                  ? "Blocked in browser settings"
                  : pushStatus === "…"
                    ? "…"
                    : "Off"}
            </p>
            <button
              type="button"
              className="btn-primary mt-3 inline-flex w-auto px-4"
              disabled={pushBusy || pushStatus === "denied"}
              onClick={() => void toggleWebPush()}
            >
              {pushBusy
                ? "Working…"
                : pushStatus === "subscribed"
                  ? "Turn off"
                  : "Enable browser notifications"}
            </button>
          </>
        )}
      </div>

      <div className="card">
        <h3 className="mb-2 font-bold">About KiddoTasks</h3>
        <p className="text-xs text-ink-secondary">
          Why we build this — and what we hope kids carry with them.
        </p>
        <button
          type="button"
          className="btn-secondary mt-3 inline-flex w-auto px-4"
          onClick={() => setAboutOpen(true)}
        >
          Read our story
        </button>
      </div>

      <Modal
        open={aboutOpen}
        title={ABOUT_TITLE}
        description={ABOUT_TAGLINE}
        onClose={() => setAboutOpen(false)}
      >
        <div className="max-h-[60vh] space-y-3 overflow-y-auto text-left text-sm leading-relaxed text-ink-secondary">
          {ABOUT_PARAGRAPHS.map((p, i) => (
            <p key={i} className={p === "But the goal is bigger than earning points." ? "font-semibold text-ink" : undefined}>
              {p}
            </p>
          ))}
          <div className="rounded-xl border border-primary/30 bg-primary-light/40 p-3">
            <p className="font-semibold text-ink">{ABOUT_CLOSING}</p>
            <p className="mt-2 text-xs font-semibold text-primary">{ABOUT_SIGNOFF}</p>
          </div>
        </div>
        <button type="button" className="btn-primary mt-4" onClick={() => setAboutOpen(false)}>
          Close
        </button>
      </Modal>
    </div>
  );
}
