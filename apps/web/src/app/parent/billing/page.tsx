"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getAuth } from "firebase/auth";
import { isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { PREMIUM_BENEFITS, PLANS } from "@/lib/billing/plans";
import { Modal } from "@/components/ui/modal";

type SubStatus = {
  premium: boolean;
  plan: string;
  status: string;
  amount: number | null;
  currency: string | null;
  currentPeriodEnd: string | null;
  cancelAtPeriodEnd: boolean;
  providerSubscriptionId: string | null;
  liveStatus: string | null;
} | null;

async function authHeaders(): Promise<HeadersInit | null> {
  if (!isFirebaseConfigured) return null;
  const user = getAuth().currentUser;
  if (!user) return null;
  const token = await user.getIdToken();
  return { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
}

export default function BillingPage() {
  const router = useRouter();
  const ent = useEntitlements();
  const loadFamily = useFamilyStore((s) => s.loadFamilyForParent);
  const parentUid = useFamilyStore((s) => s.parentUid);
  const [sub, setSub] = useState<SubStatus>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showDetails, setShowDetails] = useState(false);
  const [cancelConfirm, setCancelConfirm] = useState(false);

  const plan = PLANS.premium_monthly;

  const refresh = useCallback(async () => {
    const headers = await authHeaders();
    if (!headers) return;
    try {
      const res = await fetch("/api/billing/subscription", { headers, cache: "no-store" });
      if (!res.ok) return;
      setSub((await res.json()) as SubStatus);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  async function startCheckout() {
    setBusy(true);
    setError(null);
    try {
      const headers = await authHeaders();
      if (!headers) {
        setError("Sign in to upgrade.");
        return;
      }
      const res = await fetch("/api/billing/checkout", {
        method: "POST",
        headers,
        body: JSON.stringify({ plan: "premium_monthly" }),
      });
      const data = (await res.json()) as { url?: string; error?: string };
      if (data.url) {
        window.location.href = data.url;
        return;
      }
      setError(data.error ?? "Checkout isn’t available yet.");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Checkout failed");
    } finally {
      setBusy(false);
    }
  }

  async function cancelSub() {
    setBusy(true);
    setError(null);
    try {
      const headers = await authHeaders();
      if (!headers) return;
      const res = await fetch("/api/billing/cancel", { method: "POST", headers });
      const data = (await res.json()) as { error?: string };
      if (!res.ok) {
        setError(data.error ?? "Could not cancel.");
        return;
      }
      setCancelConfirm(false);
      await refresh();
      if (parentUid) await loadFamily(parentUid);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not cancel.");
    } finally {
      setBusy(false);
    }
  }

  const isPremium = ent.isOwner || ent.isPlus || sub?.premium;
  const statusLabel = ent.isOwner
    ? "Founder"
    : sub?.status === "active"
      ? "Active"
      : sub?.status === "past_due"
        ? "Past due"
        : sub?.status === "canceled"
          ? "Canceled"
          : ent.plan !== "free"
            ? "Active"
            : "Free";

  return (
    <div className="space-y-4">
      <div className="card">
        <h2 className="text-xl font-bold">Your plan</h2>
        <p className="mt-2 text-3xl font-bold">
          {isPremium ? "KiddoTasks Premium" : "KiddoTasks Free"}
        </p>
        <p className="mt-1 text-sm text-ink-secondary">
          {isPremium ? plan.display : "Upgrade to unlock Premium"}
        </p>
        <p className="mt-2 inline-flex items-center gap-2 rounded-pill bg-surface px-3 py-1 text-xs font-bold">
          <span
            className={`inline-block h-2 w-2 rounded-full ${
              isPremium ? "bg-success" : "bg-ink-tertiary"
            }`}
            aria-hidden
          />
          {statusLabel}
        </p>
        {(sub?.currentPeriodEnd || ent.currentPeriodEnd) && (
          <p className="mt-2 text-sm text-ink-secondary">
            Next billing:{" "}
            {new Date(
              (sub?.currentPeriodEnd ?? ent.currentPeriodEnd) as string
            ).toLocaleDateString()}
          </p>
        )}
        {ent.isOwner && (
          <p className="mt-2 text-xs text-ink-tertiary">
            Founder account — always Premium. No charge.
          </p>
        )}
      </div>

      {!isPremium && (
        <div className="card ring-2 ring-primary">
          <h3 className="font-bold">KiddoTasks Premium</h3>
          <p className="mt-1 text-2xl font-bold">
            {plan.display.replace("/month", "")}
            <span className="text-sm font-medium text-ink-secondary"> /month</span>
          </p>
          <p className="mt-1 text-xs text-ink-tertiary">{plan.billingNote}</p>
          <ul className="mt-3 space-y-1.5 text-sm text-ink-secondary">
            {PREMIUM_BENEFITS.map((b) => (
              <li key={b}>✓ {b}</li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-ink-tertiary">
            Secure checkout via PayMongo (cards, GCash, Maya). You can cancel anytime.
          </p>
          <button
            type="button"
            className="btn-primary mt-4"
            onClick={startCheckout}
            disabled={busy || !isFirebaseConfigured}
          >
            {busy ? "Redirecting…" : `Start Premium — ${plan.display}`}
          </button>
          {error && (
            <p className="field-error" role="alert">
              {error}
            </p>
          )}
        </div>
      )}

      {isPremium && !ent.isOwner && (
        <div className="card">
          <h3 className="font-bold">Manage subscription</h3>
          <p className="mt-1 text-sm text-ink-secondary">
            {plan.billingNote}
          </p>
          {sub?.providerSubscriptionId && (
            <p className="mt-2 break-all text-xs text-ink-tertiary">
              ID: {sub.providerSubscriptionId}
            </p>
          )}
          <div className="mt-4 flex flex-wrap gap-2">
            <button type="button" className="btn-secondary" onClick={() => setShowDetails(true)}>
              Plan details
            </button>
            <button
              type="button"
              className="btn-secondary"
              onClick={() => setCancelConfirm(true)}
              disabled={busy}
            >
              Cancel subscription
            </button>
          </div>
          {error && (
            <p className="field-error" role="alert">
              {error}
            </p>
          )}
        </div>
      )}

      <p className="text-xs text-ink-tertiary">
        Premium is activated only after PayMongo confirms payment. Redirecting back does
        not unlock access by itself.
      </p>

      <Modal
        open={showDetails}
        title="Premium details"
        description="What you get with KiddoTasks Premium"
        onClose={() => setShowDetails(false)}
      >
        <ul className="space-y-2 text-sm text-ink-secondary">
          {PREMIUM_BENEFITS.map((b) => (
            <li key={b}>✓ {b}</li>
          ))}
        </ul>
        <p className="mt-4 text-xs text-ink-tertiary">{plan.billingNote}</p>
      </Modal>

      <Modal
        open={cancelConfirm}
        title="Cancel Premium?"
        description="Your Premium features will stop after cancellation. You can subscribe again later."
        onClose={() => setCancelConfirm(false)}
      >
        <div className="mt-4 space-y-2">
          <button type="button" className="btn-primary" disabled={busy} onClick={cancelSub}>
            {busy ? "Canceling…" : "Yes, cancel subscription"}
          </button>
          <button type="button" className="btn-secondary" onClick={() => setCancelConfirm(false)}>
            Keep Premium
          </button>
        </div>
      </Modal>
    </div>
  );
}
