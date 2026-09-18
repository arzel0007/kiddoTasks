"use client";

import { useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { IconTile } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";
import { toast } from "@/components/toast";

export default function RewardsPage() {
  const { rewards, loading, setRewardActive, removeReward } = useFamilyStore();
  const [pendingDelete, setPendingDelete] = useState<string | null>(null);
  const active = rewards.filter((r) => r.isActive);
  const archived = rewards.filter((r) => !r.isActive);

  function archiveReward(id: string, name: string) {
    try {
      setRewardActive(id, false);
      toast.success(`Archived “${name}”.`);
    } catch {
      toast.error("Couldn’t archive reward.");
    }
  }

  function restoreReward(id: string, name: string) {
    try {
      setRewardActive(id, true);
      toast.success(`Restored “${name}”.`);
    } catch {
      toast.error("Couldn’t restore reward.");
    }
  }

  function deleteReward(id: string) {
    try {
      const reward = rewards.find((r) => r.id === id);
      if (!reward) {
        toast.error("Couldn’t find that reward.");
        return;
      }
      removeReward(id);
      setPendingDelete(null);
      toast.success(`Deleted “${reward.name}”.`);
    } catch {
      toast.error("Couldn’t delete reward.");
    }
  }

  return (
    <div className="space-y-4">
      <div className="card">
        <h2 className="mb-3 font-bold">Active rewards</h2>
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
                  <p className="text-sm text-ink-secondary line-clamp-2">{r.description}</p>
                  <p className="mt-2 text-sm font-bold text-primary">★ {r.pointCost}</p>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <button
                      type="button"
                      className="btn-secondary !px-2 !py-1 !text-xs"
                      onClick={() => archiveReward(r.id, r.name)}
                    >
                      Archive
                    </button>
                    <button
                      type="button"
                      className="btn-secondary !px-2 !py-1 !text-xs !text-attention"
                      onClick={() => setPendingDelete(r.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      {archived.length > 0 && (
        <div className="card">
          <h2 className="mb-3 font-bold">Archived</h2>
          <ul className="divide-y divide-border">
            {archived.map((r) => (
              <li key={r.id} className="flex items-center gap-3 py-3">
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{r.name}</p>
                  <p className="text-xs text-ink-tertiary">Archived</p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <button
                    type="button"
                    className="btn-secondary !px-2 !py-1 !text-xs"
                    onClick={() => restoreReward(r.id, r.name)}
                  >
                    Restore
                  </button>
                  <button
                    type="button"
                    className="btn-secondary !px-2 !py-1 !text-xs !text-attention"
                    onClick={() => setPendingDelete(r.id)}
                  >
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      {pendingDelete && (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
        >
          <div className="card w-full max-w-sm">
            <p className="font-bold">Delete this reward?</p>
            <p className="mt-1 text-sm text-ink-secondary">
              Kids can no longer claim it. Manage full reward editing on iOS.
            </p>
            <div className="mt-4 flex justify-end gap-2">
              <button type="button" className="btn-secondary" onClick={() => setPendingDelete(null)}>
                Cancel
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={() => deleteReward(pendingDelete)}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
