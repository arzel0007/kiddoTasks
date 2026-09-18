"use client";

import Link from "next/link";
import type { PlanDisplay } from "@/lib/billing/plan-status";

/** Shared “Your plan” summary — used on Plan tab and Family tab. */
export function PlanStatusSummary({
  plan,
  compact = false,
  href = "/parent/billing",
  actionLabel = "Manage billing",
}: {
  plan: PlanDisplay;
  compact?: boolean;
  href?: string;
  actionLabel?: string;
}) {
  return (
    <div className="card">
      <h3 className={compact ? "mb-2 font-bold" : "text-xl font-bold"}>
        {compact ? "Plan" : "Your plan"}
      </h3>
      <p className={compact ? "text-lg font-bold" : "mt-2 text-3xl font-bold"}>
        {plan.title}
      </p>
      <p className="mt-1 text-sm text-ink-secondary">{plan.subtitle}</p>
      <p className="mt-2 inline-flex items-center gap-2 rounded-pill bg-surface px-3 py-1 text-xs font-bold">
        <span
          className={`inline-block h-2 w-2 rounded-full ${
            plan.statusTone === "success" ? "bg-success" : "bg-ink-tertiary"
          }`}
          aria-hidden
        />
        {plan.statusLabel}
      </p>
      {plan.periodEnd ? (
        <p className="mt-2 text-sm text-ink-secondary">Next billing: {plan.periodEnd}</p>
      ) : null}
      {plan.ownerNote ? (
        <p className="mt-2 text-xs text-ink-tertiary">{plan.ownerNote}</p>
      ) : null}
      {!plan.isPremium ? (
        <p className="mt-2 text-xs text-ink-tertiary">
          {plan.freeSummary} · Premium {plan.premiumPrice} for co-parent join & unlimited kids/chores.
        </p>
      ) : null}
      <Link href={href} className="btn-secondary mt-3 inline-flex w-auto px-4">
        {plan.isPremium && !compact
          ? actionLabel
          : "Open Plan tab"}
      </Link>
    </div>
  );
}
