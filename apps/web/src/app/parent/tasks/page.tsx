"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { IconTile } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";

export default function TasksPage() {
  const { tasks, loading } = useFamilyStore();
  const [search, setSearch] = useState("");
  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return tasks.filter(
      (t) =>
        t.isActive &&
        (!q ||
          t.name.toLowerCase().includes(q) ||
          (t.description ?? "").toLowerCase().includes(q))
    );
  }, [tasks, search]);

  return (
    <div className="space-y-4">
      <input
        className="field-input"
        placeholder="Search chores…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="card">
        <h2 className="mb-3 font-bold">Active chores</h2>
        {loading ? (
          <div className="space-y-3">
            <SkeletonListRow />
            <SkeletonListRow />
            <SkeletonListRow />
          </div>
        ) : filtered.length === 0 ? (
          <p className="text-sm text-ink-secondary">
            {search
              ? `No chores match “${search}”.`
              : "No chores yet. Add them from the iOS app for the full editor."}
          </p>
        ) : (
          <ul className="divide-y divide-border">
            {filtered.map((t) => (
              <li key={t.id} className="flex items-center gap-3 py-3">
                <IconTile icon={t.icon} category={t.category} />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{t.name}</p>
                  <p className="text-sm text-ink-secondary">
                    ★ {t.pointValue} · {t.category}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
      <p className="text-xs text-ink-tertiary">
        Icons match the iOS SF Symbol picker.{" "}
        <Link href="/parent/today" className="text-primary underline">
          Back to Today
        </Link>
      </p>
    </div>
  );
}
