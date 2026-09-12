"use client";

import { useState } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";

export default function BillingPage() {
  const ent = useEntitlements();
  const family = useFamilyStore((s) => s.family);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  async function startCheckout() {
    setBusy(true);
    setNote(null);
    try {
      const res = await fetch("/api/stripe/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ plan: "plus", familyId: family?.id }),
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
        return;
      }
      setNote(data.error ?? "Checkout isn’t configured yet (Stripe keys).");
    } catch (e) {
      setNote(e instanceof Error ? e.message : "Checkout failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="card">
        <h2 className="text-xl font-bold">Your plan</h2>
        <p className="mt-2 text-3xl font-bold capitalize">{ent.plan}</p>
        <p className="text-sm text-ink-secondary capitalize">{ent.status}</p>
        {ent.currentPeriodEnd && (
          <p className="text-sm text-ink-secondary">
            Renews {ent.currentPeriodEnd.slice(0, 10)}
          </p>
        )}
      </div>

      <div className="card">
        <h3 className="font-bold">Family Plus — $6/mo</h3>
        <ul className="mt-2 space-y-1 text-sm text-ink-secondary">
          <li>• Unlimited kids</li>
          <li>• Full history + export</li>
          <li>• Custom reward photos</li>
        </ul>
        <button
          type="button"
          className="btn-primary mt-4"
          onClick={startCheckout}
          disabled={busy || ent.isPlus}
        >
          {ent.isPlus ? "You’re on Plus" : busy ? "Redirecting…" : "Upgrade with Stripe"}
        </button>
        {note && <p className="mt-3 text-sm text-warning">{note}</p>}
        <p className="mt-3 text-xs text-ink-tertiary">
          Add STRIPE_SECRET_KEY and price IDs in apps/web/.env.local, then implement
          the webhook to write entitlements.
        </p>
      </div>
    </div>
  );
}
