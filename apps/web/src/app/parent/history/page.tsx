"use client";

import { useMemo } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { FREE_LIMITS } from "@/lib/entitlements";
import { SkeletonListRow } from "@/components/skeleton";

/** Firestore may store Timestamp, Date, string, or seconds. */
function toMs(value: unknown): number {
  if (value == null) return 0;
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : 0;
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "object") {
    const o = value as Record<string, unknown>;
    if (typeof o.toMillis === "function") {
      try {
        return (o.toMillis as () => number)();
      } catch {
        /* ignore */
      }
    }
    if (typeof o.seconds === "number") return o.seconds * 1000;
    if (typeof o._seconds === "number") return o._seconds * 1000;
  }
  return 0;
}

function formatDate(value: unknown): string {
  const ms = toMs(value);
  if (!ms) return "";
  try {
    return ` · ${new Date(ms).toISOString().slice(0, 10)}`;
  } catch {
    return "";
  }
}

export default function HistoryPage() {
  const { transactions, children, loading } = useFamilyStore();
  const ent = useEntitlements();

  const sorted = useMemo(
    () =>
      [...transactions].sort(
        (a, b) => toMs(b.createdAt) - toMs(a.createdAt)
      ),
    [transactions]
  );

  // Free tier: only show last 7 days worth (approx by count if no dates)
  const visible = ent.isPlus ? sorted : sorted.slice(0, 20);

  return (
    <div className="card">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="font-bold">History</h2>
        {!ent.isPlus && (
          <span className="text-xs text-ink-secondary">
            Free: recent only
          </span>
        )}
      </div>
      {loading ? (
        <div className="space-y-3">
          <SkeletonListRow />
          <SkeletonListRow />
          <SkeletonListRow />
        </div>
      ) : visible.length === 0 ? (
        <p className="text-sm text-ink-secondary">
          No activity yet. Completions and rewards will appear here.
        </p>
      ) : (
        <ul className="divide-y divide-border">
          {visible.map((tx) => (
            <li key={tx.id} className="flex items-center gap-3 py-3">
              <div
                className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold text-white ${
                  tx.amount >= 0 ? "bg-success" : "bg-error"
                }`}
              >
                {tx.amount >= 0 ? "+" : "−"}
              </div>
              <div className="flex-1 min-w-0">
                <p className="truncate text-sm font-semibold">
                  {children.find((c) => c.id === tx.childId)?.name ?? "Child"}
                  <span className="font-normal text-ink-secondary">
                    {" · "}
                    {tx.description}
                  </span>
                </p>
                <p className="text-xs text-ink-secondary">
                  {tx.type?.replace(/_/g, " ").toLowerCase() ?? "activity"}
                  {formatDate(tx.createdAt)}
                </p>
              </div>
              <span
                className={`font-bold tabular-nums ${
                  tx.amount >= 0 ? "text-success" : "text-error"
                }`}
              >
                {tx.amount > 0 ? `+${tx.amount}` : tx.amount}
              </span>
            </li>
          ))}
        </ul>
      )}
      {!ent.isPlus && (
        <a href="/parent/billing" className="btn-secondary mt-4">
          Unlock full history
        </a>
      )}
      <p className="mt-3 text-xs text-ink-tertiary">
        Free history window: {FREE_LIMITS.historyDays} days (soft limit in v1).
      </p>
    </div>
  );
}
