"use client";

import { useState } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { FREE_LIMITS } from "@/lib/entitlements";
import { ChildAvatar } from "@/lib/ui";
import { PageSkeleton } from "@/components/skeleton";
import { ALLOWANCE_MODES, type AllowanceMode } from "@/lib/entitlements";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import { isWishlistEnabled } from "@/lib/wishlist";
import { computePlanDisplay } from "@/lib/billing/plan-status";
import { PlanStatusSummary } from "@/components/plan-status-summary";

export default function FamilyPage() {
  const { family, children, loading, setEnableWishlist, parentEmail } = useFamilyStore();
  const ent = useEntitlements();
  const planDisplay = computePlanDisplay(ent, parentEmail);
  const [mode, setMode] = useState<AllowanceMode>(
    (family?.settings?.allowanceMode as AllowanceMode) || "STARS_ONLY"
  );
  const [flatAmount, setFlatAmount] = useState(
    String(family?.settings?.flatDailyAmount ?? 1)
  );
  const [weekBonus, setWeekBonus] = useState(
    family?.settings?.weekBonusTitle || "Full week!"
  );
  const [wishlistBusy, setWishlistBusy] = useState(false);
  const wishlistOn = isWishlistEnabled(family);

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
      {!family ? (
        <div className="card border-error/40">
          <p className="font-semibold text-error">
            Family data didn’t load. Check your connection or sign out and back in.
          </p>
          <p className="mt-1 text-sm text-ink-secondary">
            The Wishlist toggle needs a loaded family. If Tasks/Rewards are also empty,
            deploy Firestore rules and hard-refresh.
          </p>
        </div>
      ) : null}
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

      <div className="card">
        <h3 className="mb-2 font-bold">Allowance</h3>
        <p className="mb-2 text-xs text-ink-secondary">
          Stars stay in the app. These modes help you know what to pay out.
        </p>
        <div className="flex flex-wrap gap-2">
          {ALLOWANCE_MODES.map((m) => (
            <button
              key={m.id}
              type="button"
              className={`rounded-full px-3 py-2 text-sm font-semibold ${
                mode === m.id
                  ? "bg-primary text-white"
                  : "bg-surface text-ink-secondary"
              }`}
              onClick={() => {
                setMode(m.id);
                toast.success(`Allowance mode set to ${m.label}.`);
              }}
            >
              {m.label}
            </button>
          ))}
        </div>
        {mode === "FLAT_DAILY" && (
          <label className="mt-3 block text-sm">
            <span className="text-ink-secondary">Daily amount when something is done</span>
            <input
              type="number"
              min={0}
              className="field-input mt-1"
              value={flatAmount}
              onChange={(e) => setFlatAmount(e.target.value)}
              onBlur={() => toast.success("Daily amount saved.")}
            />
          </label>
        )}
        <p className="mt-2 text-xs text-ink-tertiary">
          Settings save locally in this web build; full cloud write can be wired to the iOS store API next.
        </p>
      </div>

      <div className="card">
        <h3 className="mb-2 font-bold">Week bonus</h3>
        <p className="text-xs text-ink-secondary">
          Celebrate when a child has progress every day of the week.
        </p>
        <input
          className="field-input mt-2"
          placeholder="Full week!"
          defaultValue={weekBonus}
          onBlur={(e) => {
            const next = e.target.value || "Full week!";
            setWeekBonus(next);
            toast.success("Week bonus saved.");
          }}
        />
      </div>

      <PlanStatusSummary plan={planDisplay} compact />
    </div>
  );
}
