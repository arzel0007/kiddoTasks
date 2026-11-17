"use client";

import { useState } from "react";
import { useFamilyStore } from "@/lib/family-store";

export function FamilyLoadError({ message }: { message?: string | null }) {
  const parentUid = useFamilyStore((s) => s.parentUid);
  const loadFamilyForParent = useFamilyStore((s) => s.loadFamilyForParent);
  const [retrying, setRetrying] = useState(false);

  async function retry() {
    if (!parentUid) return;
    setRetrying(true);
    try {
      await loadFamilyForParent(parentUid);
    } finally {
      setRetrying(false);
    }
  }

  return (
    <div className="card border-error/40" role="alert">
      <p className="font-semibold text-error">We couldn’t load your family</p>
      <p className="mt-1 text-sm text-ink-secondary">
        {message || "Check your connection, then try again."}
      </p>
      {parentUid ? (
        <button
          className="btn-secondary mt-3 inline-flex w-auto px-4"
          type="button"
          disabled={retrying}
          onClick={() => void retry()}
        >
          {retrying ? "Trying again…" : "Try again"}
        </button>
      ) : null}
    </div>
  );
}
