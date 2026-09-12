"use client";

import { useState } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { FREE_LIMITS } from "@/lib/entitlements";
import { ChildAvatar } from "@/lib/ui";
import { PageSkeleton } from "@/components/skeleton";
import { ALLOWANCE_MODES, type AllowanceMode } from "@/lib/entitlements";

export default function FamilyPage() {
  const { family, children, loading } = useFamilyStore();
  const ent = useEntitlements();
  const [mode, setMode] = useState<AllowanceMode>(
    (family?.settings?.allowanceMode as AllowanceMode) || "STARS_ONLY"
  );
  const [flatAmount, setFlatAmount] = useState(
    String(family?.settings?.flatDailyAmount ?? 1)
  );
  const [weekBonus, setWeekBonus] = useState(
    family?.settings?.weekBonusTitle || "Full week!"
  );

  if (loading && !family) {
    return <PageSkeleton rows={2} />;
  }

  return (
    <div className="space-y-4">
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
              onClick={() => setMode(m.id)}
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
          onBlur={(e) => setWeekBonus(e.target.value || "Full week!")}
        />
      </div>

      <div className="card">
        <h3 className="mb-2 font-bold">Plan</h3>
        <p className="capitalize">
          {ent.plan} · <span className="text-ink-secondary">{ent.status}</span>
        </p>
        <p className="mt-1 text-xs text-ink-tertiary">
          Free: 1 kid · 20 chores · Premium ₱199/mo for co-parent join & unlimited.
        </p>
        <a href="/parent/billing" className="btn-secondary mt-3">
          Manage billing
        </a>
      </div>
    </div>
  );
}
