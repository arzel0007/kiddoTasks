"use client";

import { useMemo } from "react";
import Link from "next/link";
import { useFamilyStore } from "@/lib/family-store";
import { ChildAvatar } from "@/lib/ui";
import { PageSkeleton } from "@/components/skeleton";
import { IconCheck, IconGift, IconList, IconUsers } from "@/components/icons";
import { birthdayMessage, upcomingBirthdays } from "@/lib/birthdays";

export default function TodayPage() {
  const { family, children, tasks, completions, claims, rewards, loading, error } =
    useFamilyStore();

  const pendingApprovals = useMemo(
    () => completions.filter((c) => c.status === "AWAITING_APPROVAL"),
    [completions]
  );
  const pendingClaims = useMemo(
    () => claims.filter((c) => c.status === "CLAIMED"),
    [claims]
  );
  const activeTasks = tasks.filter((t) => t.isActive);
  const birthdays = useMemo(() => upcomingBirthdays(children), [children]);

  if (loading) {
    return <PageSkeleton rows={3} />;
  }

  if (error) {
    return (
      <div className="card border-error/40">
        <p className="font-semibold text-error">{error}</p>
      </div>
    );
  }

  if (!family) {
    return (
      <div className="card text-center">
        <p className="text-4xl">👋</p>
        <p className="mt-2 font-semibold">Setting up your family…</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Birthday reminders (next 7 days) */}
      {birthdays.length > 0 && (
        <div className="space-y-2">
          {birthdays.map((b) => (
            <div
              key={b.id}
              className="flex items-center gap-3 rounded-card border border-border p-3"
              style={{ background: "var(--color-reward-light)" }}
            >
              <span className="text-xl">🎂</span>
              <div>
                <p className="text-sm font-semibold">
                  {b.isToday
                    ? `Happy birthday, ${b.name}!`
                    : birthdayMessage(b)}
                </p>
                <p className="text-xs text-ink-secondary">
                  {b.isToday ? "Make their day special" : "Coming up soon"}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Metric cards — white / semantic tint only (Calm Adventure) */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <MetricCard
          label="Missions to review"
          value={pendingApprovals.length}
          icon={<IconCheck size={18} />}
        />
        <MetricCard
          label="Reward requests"
          value={pendingClaims.length}
          icon={<IconGift size={18} />}
          variant="reward"
        />
        <MetricCard
          label="Active chores"
          value={activeTasks.length}
          icon={<IconList size={18} />}
        />
        <MetricCard
          label="Kids"
          value={children.length}
          icon={<IconUsers size={18} />}
          variant="success"
        />
      </div>

      <section className="card">
        <div className="mb-3 flex items-center gap-2">
          <IconUsers size={18} className="text-primary" />
          <h2 className="font-bold">Kids today</h2>
        </div>
        {children.length === 0 ? (
          <div className="rounded-xl bg-surface p-4 text-center">
            <p className="text-sm text-ink-secondary">
              Add a child in the Family tab to get started.
            </p>
            <Link href="/parent/family" className="btn-secondary mt-3 inline-flex w-auto px-4">
              Go to Family
            </Link>
          </div>
        ) : (
          <ul className="space-y-3">
            {children.map((c) => {
              const due = activeTasks.filter(
                (t) =>
                  t.assignedChildIds.length === 0 ||
                  t.assignedChildIds.includes(c.id)
              ).length;
              return (
                <li key={c.id} className="flex items-center gap-3">
                  <ChildAvatar
                    emoji={c.avatar.emoji}
                    colorHex={c.avatar.colorHex}
                    photoURL={c.photoURL}
                    photoData={c.photoData}
                    size={44}
                    name={c.name}
                  />
                  <div className="flex-1">
                    <p className="font-semibold">{c.name}</p>
                    <p className="text-sm text-ink-secondary">{due} missions due</p>
                  </div>
                  <span
                    className="rounded-pill px-2.5 py-1 text-xs font-bold text-[#8a6420]"
                    style={{ background: "var(--color-reward-light)" }}
                  >
                    ★ {c.activePoints}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="card">
        <div className="mb-3 flex items-center gap-2">
          <IconCheck size={18} className="text-primary" />
          <h2 className="font-bold">Waiting for approval</h2>
        </div>
        {pendingApprovals.length === 0 ? (
          <p className="text-sm text-ink-secondary">No missions waiting. Nice! 🎉</p>
        ) : (
          <ul className="space-y-2">
            {pendingApprovals.map((c) => {
              const child = children.find((k) => k.id === c.childId);
              const task = tasks.find((t) => t.id === c.taskId);
              return (
                <li
                  key={c.id}
                  className="flex items-center gap-3 rounded-xl bg-surface p-3"
                >
                  {child && (
                    <ChildAvatar
                      emoji={child.avatar.emoji}
                      colorHex={child.avatar.colorHex}
                      photoURL={child.photoURL}
                      photoData={child.photoData}
                      size={36}
                      name={child.name}
                    />
                  )}
                  <div className="flex-1">
                    <p className="text-sm font-semibold">
                      {child?.name ?? "Child"}
                      {task ? ` · ${task.name}` : ""}
                    </p>
                    <p className="text-xs text-ink-secondary">Needs your approval</p>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="card">
        <div className="mb-3 flex items-center gap-2">
          <IconGift size={18} className="text-primary" />
          <h2 className="font-bold">Reward requests</h2>
        </div>
        {pendingClaims.length === 0 ? (
          <p className="text-sm text-ink-secondary">No reward requests right now.</p>
        ) : (
          <ul className="space-y-2">
            {pendingClaims.map((c) => {
              const child = children.find((k) => k.id === c.childId);
              const reward = rewards.find((r) => r.id === c.rewardId);
              return (
                <li key={c.id} className="rounded-xl bg-surface p-3">
                  <p className="text-sm font-semibold">
                    {child?.name ?? "Child"}
                    {reward ? ` wants “${reward.name}”` : " wants a reward"}
                  </p>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </div>
  );
}

function MetricCard({
  label,
  value,
  icon,
  variant,
}: {
  label: string;
  value: number;
  icon: React.ReactNode;
  variant?: "reward" | "success";
}) {
  const cls =
    variant === "reward"
      ? "metric-card metric-card--reward"
      : variant === "success"
        ? "metric-card metric-card--success"
        : "metric-card";
  const iconWrap =
    variant === "reward"
      ? "metric-card__icon"
      : variant === "success"
        ? "metric-card__icon"
        : "metric-card__icon";
  return (
    <div className={cls}>
      <div className={iconWrap}>{icon}</div>
      <p className="metric-card__value mt-2">{value}</p>
      <p className="metric-card__label mt-1">{label}</p>
    </div>
  );
}
