"use client";

import { useFamilyStore } from "@/lib/family-store";
import { IconTile } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";

export default function RewardsPage() {
  const { rewards, loading } = useFamilyStore();
  const active = rewards.filter((r) => r.isActive);

  return (
    <div className="card">
      <h2 className="mb-3 font-bold">Rewards</h2>
      {loading ? (
        <div className="space-y-3">
          <SkeletonListRow />
          <SkeletonListRow />
        </div>
      ) : active.length === 0 ? (
        <p className="text-sm text-ink-secondary">
          No rewards yet. Add them on iOS for the full editor.
        </p>
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2">
          {active.map((r) => (
            <li
              key={r.id}
              className="flex items-start gap-3 rounded-card border border-border p-3"
            >
              <IconTile icon={r.icon} reward size={48} />
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold">{r.name}</p>
                <p className="text-sm text-ink-secondary line-clamp-2">
                  {r.description}
                </p>
                <p className="mt-2 text-sm font-bold text-primary">★ {r.pointCost}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
