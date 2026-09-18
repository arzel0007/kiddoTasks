"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { getAuth } from "firebase/auth";
import { isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import { toast } from "@/components/toast";

function SuccessInner() {
  const params = useSearchParams();
  const loadFamily = useFamilyStore((s) => s.loadFamilyForParent);
  const parentUid = useFamilyStore((s) => s.parentUid);
  const [state, setState] = useState<"checking" | "active" | "pending" | "error">(
    "checking"
  );
  const [note, setNote] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let attempts = 0;

    async function poll() {
      if (cancelled || !isFirebaseConfigured) {
        setState("error");
        setNote("Billing isn’t configured.");
        toast.error("Billing isn’t configured.");
        return;
      }
      const user = getAuth().currentUser;
      if (!user) {
        setState("error");
        setNote("Sign in to confirm your subscription.");
        toast.error("Sign in to confirm your subscription.");
        return;
      }
      while (attempts < 12 && !cancelled) {
        attempts += 1;
        try {
          const token = await user.getIdToken();
          const res = await fetch("/api/billing/subscription", {
            headers: { Authorization: `Bearer ${token}` },
            cache: "no-store",
          });
          if (res.ok) {
            const data = (await res.json()) as { premium?: boolean; status?: string };
            if (data.premium || data.status === "active") {
              if (parentUid) await loadFamily(parentUid);
              setState("active");
              if (!cancelled) toast.success("You’re Premium!");
              return;
            }
          }
        } catch {
          /* retry */
        }
        await new Promise((r) => setTimeout(r, 1500));
      }
      if (!cancelled) {
        setState("pending");
        toast.info("Payment still processing — check Billing in a moment.");
      }
    }

    void poll();
    return () => {
      cancelled = true;
    };
  }, [loadFamily, parentUid]);

  const subId = params.get("sub");

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-6 py-12">
      <div className="card w-full text-center">
        {state === "checking" && (
          <>
            <div className="mx-auto mb-4 h-12 w-12 animate-pulse rounded-full bg-primary-light" />
            <h1 className="text-2xl font-bold">Confirming payment…</h1>
            <p className="mt-2 text-sm text-ink-secondary">
              Waiting for PayMongo to confirm. This usually takes a few seconds.
            </p>
          </>
        )}
        {state === "active" && (
          <>
            <p className="text-5xl">🎉</p>
            <h1 className="mt-3 text-2xl font-bold">You&apos;re Premium!</h1>
            <p className="mt-2 text-sm text-ink-secondary">
              Welcome to KiddoTasks Premium. Your family now has access to all Premium
              features.
            </p>
            <Link href="/parent/today" className="btn-primary mt-6 inline-flex w-auto px-6">
              Continue to KiddoTasks
            </Link>
          </>
        )}
        {state === "pending" && (
          <>
            <p className="text-5xl">⏳</p>
            <h1 className="mt-3 text-2xl font-bold">Payment still processing</h1>
            <p className="mt-2 text-sm text-ink-secondary">
              We haven&apos;t received confirmation yet. If you completed payment, Premium
              will unlock automatically. Check Billing in a moment.
            </p>
            {subId && (
              <p className="mt-2 break-all text-xs text-ink-tertiary">Ref: {subId}</p>
            )}
            <Link href="/parent/billing" className="btn-secondary mt-6 inline-flex w-auto px-6">
              Back to Billing
            </Link>
          </>
        )}
        {state === "error" && (
          <>
            <p className="text-5xl">💳</p>
            <h1 className="mt-3 text-2xl font-bold">Payment wasn&apos;t completed</h1>
            <p className="mt-2 text-sm text-ink-secondary">
              Your Premium subscription hasn&apos;t been activated. Please try again.
            </p>
            {note && <p className="mt-2 text-sm text-warning">{note}</p>}
            <Link href="/parent/billing" className="btn-primary mt-6 inline-flex w-auto px-6">
              Try again
            </Link>
          </>
        )}
      </div>
    </main>
  );
}

export default function BillingSuccessPage() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-screen max-w-lg items-center justify-center">
          <p className="text-sm text-ink-secondary">Loading…</p>
        </main>
      }
    >
      <SuccessInner />
    </Suspense>
  );
}
