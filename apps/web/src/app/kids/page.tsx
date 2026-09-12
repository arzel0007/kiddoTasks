"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { ChildAvatar, IconTile, sfSymbolToGlyph } from "@/lib/ui";
import { SkeletonPlayerGrid } from "@/components/skeleton";
import { BrandLogo } from "@/components/brand-logo";

/** Kids Station — works for parent-signed-in browser or PIN session. */
export default function KidsPage() {
  const router = useRouter();
  const store = useFamilyStore();
  const { family, children, tasks, completions } = store;
  const [selectedChildId, setSelectedChildId] = useState<string | null>(null);

  const canOpen = Boolean(family) || store.kidsMode;
  const selected = children.find((c) => c.id === selectedChildId) ?? null;

  const missions = useMemo(() => {
    if (!selected) return [];
    return tasks.filter(
      (t) =>
        t.isActive &&
        (t.assignedChildIds.length === 0 || t.assignedChildIds.includes(selected.id))
    );
  }, [tasks, selected]);

  if (store.loading && !family) {
    return (
      <main className="min-h-screen bg-page px-4 py-8">
        <div className="mx-auto max-w-3xl">
          <p className="mb-4 text-center text-sm text-ink-secondary">Loading…</p>
          <SkeletonPlayerGrid />
        </div>
      </main>
    );
  }

  if (!canOpen) {
    return (
      <main className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-6 text-center">
        <div className="card w-full">
          <p className="text-5xl">🔒</p>
          <h1 className="mt-3 text-2xl font-bold">Kids Station</h1>
          <p className="mt-2 text-sm text-ink-secondary">
            Sign in as a parent, or unlock with the family PIN.
          </p>
          <div className="mt-5 space-y-2">
            <button type="button" className="btn-primary" onClick={() => router.push("/")}>
              Enter family PIN
            </button>
            <button
              type="button"
              className="btn-secondary"
              onClick={() => router.push("/")}
            >
              Parent sign in
            </button>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-page pb-16">
      <div className="mx-auto max-w-3xl px-4 py-6">
        {/* Top bar */}
        <div className="mb-5 flex items-center justify-between">
          <Link
            href={store.parentUid ? "/parent/today" : "/"}
            className="rounded-full bg-white/80 px-3 py-1.5 text-xs font-bold text-ink-secondary shadow-card"
          >
            Parent
          </Link>
          <div className="flex items-center gap-2">
            <BrandLogo size={28} />
            <h1 className="text-lg font-bold text-ink">Who&apos;s playing?</h1>
          </div>
          <div className="w-16" />
        </div>

        {!selected ? (
          <>
            <p className="mb-4 text-center text-sm text-ink-secondary">
              Pick your face to start
            </p>
            {children.length === 0 ? (
              <div className="card mx-auto max-w-md text-center">
                <p className="text-4xl">🧒</p>
                <p className="mt-2 font-semibold">No kids yet</p>
                <p className="mt-1 text-sm text-ink-secondary">
                  Ask a parent to add a child in Family.
                </p>
                {store.parentUid && (
                  <Link href="/parent/family" className="btn-secondary mt-4 inline-flex w-auto px-4">
                    Family settings
                  </Link>
                )}
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
                {children.map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => setSelectedChildId(c.id)}
                    className="card flex flex-col items-center gap-3 py-7 transition hover:-translate-y-0.5 hover:shadow-cardlg"
                    style={{ borderColor: `${c.avatar.colorHex}55`, borderWidth: 2 }}
                  >
                    <ChildAvatar
                      emoji={c.avatar.emoji}
                      colorHex={c.avatar.colorHex}
                      photoURL={c.photoURL}
                      photoData={c.photoData}
                      size={80}
                      name={c.name}
                    />
                    <p className="text-base font-bold">{c.name}</p>
                    <span className="rounded-pill bg-reward-light px-2.5 py-1 text-xs font-bold text-[#8a6420]">
                      ★ {c.activePoints}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </>
        ) : (
          <div>
            <div
              className="mb-5 rounded-card p-5 text-white shadow-card"
              style={{ background: selected.avatar.colorHex }}
            >
              <div className="flex items-center gap-3">
                <ChildAvatar
                  emoji={selected.avatar.emoji}
                  colorHex="#ffffff"
                  photoURL={selected.photoURL}
                  photoData={selected.photoData}
                  size={56}
                  name={selected.name}
                />
                <div className="flex-1">
                  <p className="text-xs font-semibold uppercase tracking-wide opacity-90">
                    Missions
                  </p>
                  <p className="text-2xl font-bold">Hi, {selected.name}!</p>
                </div>
                <span className="rounded-full bg-white/20 px-3 py-1.5 text-sm font-bold">
                  ★ {selected.activePoints}
                </span>
              </div>
            </div>

            <button
              type="button"
              className="mb-4 text-sm font-semibold text-primary"
              onClick={() => setSelectedChildId(null)}
            >
              ← Switch player
            </button>

            {missions.length === 0 ? (
              <div className="card text-center">
                <p className="text-4xl">🎯</p>
                <p className="mt-2 font-bold">All clear</p>
                <p className="text-sm text-ink-secondary">No missions for today.</p>
              </div>
            ) : (
              <ul className="space-y-3">
                {missions.map((t) => {
                  const done = completions.find(
                    (c) =>
                      c.taskId === t.id &&
                      c.childId === selected.id &&
                      c.status !== "REJECTED"
                  );
                  return (
                    <li
                      key={t.id}
                      className={`card flex items-center gap-3 ${done ? "opacity-60" : ""}`}
                    >
                      <IconTile icon={t.icon} category={t.category} size={48} />
                      <div className="flex-1">
                        <p className="font-bold">{t.name}</p>
                        <p className="text-sm text-ink-secondary">
                          {done
                            ? done.status.replace("_", " ").toLowerCase()
                            : sfSymbolToGlyph(t.icon) + " Ready"}
                        </p>
                      </div>
                      <span className="rounded-pill bg-surface px-2.5 py-1 text-xs font-bold text-primary">
                        ★ {t.pointValue}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
