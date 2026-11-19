"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useFamilyStore, useEntitlements } from "@/lib/family-store";
import { IconTile, ChildAvatar } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";
import { Modal } from "@/components/ui/modal";
import { FormField } from "@/components/ui/form-field";
import { FamilyLoadError } from "@/components/family-load-error";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import {
  TASK_APPROVAL_OPTIONS,
  TASK_CATEGORIES,
  TASK_ICONS,
  TASK_RECURRENCE_OPTIONS,
} from "@/lib/catalog";
import { canAddTask } from "@/lib/entitlements";
import type { KiddoTask, TaskApprovalBehavior, TaskRecurrenceType } from "@/lib/types";

type TaskForm = {
  name: string;
  description: string;
  icon: string;
  category: string;
  pointValue: number;
  approvalBehavior: TaskApprovalBehavior;
  assignedChildIds: string[];
  recurrence: TaskRecurrenceType;
};

const emptyForm: TaskForm = {
  name: "",
  description: "",
  icon: "checkmark.circle",
  category: "household",
  pointValue: 10,
  approvalBehavior: "useFamilyDefault",
  assignedChildIds: [],
  recurrence: "daily",
};

export default function TasksPage() {
  const {
    family,
    tasks,
    children,
    loading,
    parentEmail,
    error,
    addTask,
    updateTask,
    setTaskActive,
  } = useFamilyStore();
  const ent = useEntitlements();
  const [search, setSearch] = useState("");
  const [showArchived, setShowArchived] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<TaskForm>(emptyForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const premium = ent.isPlus;
  const canCreate = canAddTask(tasks.length, parentEmail, premium);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const pool = showArchived ? tasks.filter((t) => !t.isActive) : tasks.filter((t) => t.isActive);
    return pool.filter(
      (t) =>
        !q ||
        t.name.toLowerCase().includes(q) ||
        (t.description ?? "").toLowerCase().includes(q)
    );
  }, [tasks, search, showArchived]);

  function openCreate() {
    if (!canCreate) {
      toast.error("Free plan includes up to 20 chores. Upgrade to add more.");
      return;
    }
    setEditingId(null);
    setForm(emptyForm);
    setFormError(null);
    setEditorOpen(true);
  }

  function openEdit(task: KiddoTask) {
    setEditingId(task.id);
    setForm({
      name: task.name,
      description: task.description ?? "",
      icon: task.icon || "checkmark.circle",
      category: task.category || "household",
      pointValue: task.pointValue,
      approvalBehavior: (task.approvalBehavior as TaskApprovalBehavior) || "useFamilyDefault",
      assignedChildIds: task.assignedChildIds ?? [],
      recurrence: (task.recurrence?.type as TaskRecurrenceType) || "oneTime",
    });
    setFormError(null);
    setEditorOpen(true);
  }

  async function saveForm(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setFormError(null);
    try {
      const payload = {
        name: form.name,
        description: form.description,
        icon: form.icon,
        category: form.category,
        pointValue: form.pointValue,
        approvalBehavior: form.approvalBehavior,
        assignedChildIds: form.assignedChildIds,
        recurrence: form.recurrence,
      };
      if (editingId) {
        await updateTask(editingId, payload);
        toast.success(`Updated “${payload.name.trim()}”.`);
      } else {
        await addTask(payload);
        toast.success(`Added “${payload.name.trim()}”.`);
      }
      setEditorOpen(false);
    } catch (err) {
      const msg = errorMessage(err, "Couldn’t save chore.");
      setFormError(msg);
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(task: KiddoTask) {
    setBusyId(task.id);
    const next = !task.isActive;
    try {
      await setTaskActive(task.id, next);
      toast.success(next ? `Restored “${task.name}”.` : `Archived “${task.name}”.`);
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t update chore."));
    } finally {
      setBusyId(null);
    }
  }

  function toggleAssigned(childId: string) {
    setForm((f) => ({
      ...f,
      assignedChildIds: f.assignedChildIds.includes(childId)
        ? f.assignedChildIds.filter((id) => id !== childId)
        : [...f.assignedChildIds, childId],
    }));
  }

  function handleTaskSegmentKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    const selectedIndex = showArchived ? 1 : 0;
    let nextIndex: number | undefined;
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      nextIndex = (selectedIndex + 1) % 2;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = 1;
    }
    if (nextIndex === undefined) return;
    event.preventDefault();
    setShowArchived(nextIndex === 1);
    event.currentTarget.querySelectorAll<HTMLButtonElement>('[role="tab"]')[nextIndex]?.focus();
  }

  return (
    <div className="space-y-4">
      {error ? (
        <FamilyLoadError message={error} />
      ) : null}
      <div className="relative">
        <span
          aria-hidden="true"
          className="pointer-events-none absolute left-3 top-1/2 z-[1] -translate-y-1/2 text-base leading-none text-ink-secondary"
        >
          🔍
        </span>
        <input
          className="field-input field-input--search"
          placeholder="Search chores…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          aria-label="Search chores"
        />
        {search ? (
          <button
            type="button"
            aria-label="Clear search"
            className="absolute right-2 top-1/2 z-[1] -translate-y-1/2 rounded-full px-2 py-1 text-sm text-ink-tertiary hover:text-ink"
            onClick={() => setSearch("")}
          >
            ✕
          </button>
        ) : null}
      </div>

      <div className="card">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div
            className="task-segment"
            role="tablist"
            aria-label="Chore lists"
            onKeyDown={handleTaskSegmentKeyDown}
          >
            <span
              className="task-segment__thumb"
              aria-hidden="true"
              style={{ transform: `translateX(${showArchived ? "calc(100% + 0.2rem)" : "0"})` }}
            />
            <button
              id="active-chores-tab"
              type="button"
              role="tab"
              aria-selected={!showArchived}
              aria-controls="task-list-panel"
              tabIndex={showArchived ? -1 : 0}
              className="task-segment__button"
              onClick={() => setShowArchived(false)}
            >
              Active
            </button>
            <button
              id="archived-chores-tab"
              type="button"
              role="tab"
              aria-selected={showArchived}
              aria-controls="task-list-panel"
              tabIndex={showArchived ? 0 : -1}
              className="task-segment__button"
              onClick={() => setShowArchived(true)}
            >
              Archived
            </button>
          </div>
          <button type="button" className="chip-btn chip-btn--primary" onClick={openCreate}>
            + Add chore
          </button>
        </div>
        <section
          key={showArchived ? "archived" : "active"}
          id="task-list-panel"
          role="tabpanel"
          aria-labelledby={showArchived ? "archived-chores-tab" : "active-chores-tab"}
          tabIndex={0}
          className={`task-list-panel ${showArchived ? "task-list-panel--forward" : "task-list-panel--back"}`}
        >
        <h2 className="sr-only">{showArchived ? "Archived chores" : "Active chores"}</h2>
        {loading && !family ? (
          <div className="space-y-3">
            <SkeletonListRow />
            <SkeletonListRow />
            <SkeletonListRow />
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center">
            <p className="text-sm text-ink-secondary">
              {search
                ? `No chores match “${search}”.`
                : showArchived
                  ? "No archived chores."
                  : "No chores yet. Add the first mission for your family."}
            </p>
            {!showArchived && (
              <button
                type="button"
                className="btn-secondary mt-3 inline-flex w-auto px-4"
                onClick={openCreate}
              >
                Add chore
              </button>
            )}
          </div>
        ) : (
          <ul className="motion-stagger divide-y divide-border">
            {filtered.map((t) => (
              <li key={t.id} className="flex items-center gap-3 py-3">
                <IconTile icon={t.icon} category={t.category} />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{t.name}</p>
                  <p className="text-sm text-ink-secondary">
                    ★ {t.pointValue} · {t.category}
                    {t.assignedChildIds?.length
                      ? ` · ${t.assignedChildIds.length} kid${t.assignedChildIds.length > 1 ? "s" : ""}`
                      : " · all kids"}
                  </p>
                </div>
                <div className="flex shrink-0 gap-1.5">
                  <button
                    type="button"
                    className="btn-secondary btn-compact"
                    disabled={busyId === t.id}
                    onClick={() => openEdit(t)}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className="btn-secondary btn-compact"
                    disabled={busyId === t.id}
                    onClick={() => void toggleActive(t)}
                  >
                    {busyId === t.id ? "…" : t.isActive ? "Archive" : "Restore"}
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
        </section>
      </div>

      <p className="text-xs text-ink-tertiary">
        Icons match the iOS SF Symbol picker.{" "}
        <Link href="/parent/today" className="text-primary underline">
          Back to Today
        </Link>
      </p>

      <Modal
        open={editorOpen}
        title={editingId ? "Edit chore" : "Add chore"}
        description="Missions kids complete to earn stars."
        onClose={() => {
          if (!saving) setEditorOpen(false);
        }}
      >
        <form onSubmit={saveForm} className="space-y-3 text-left">
          <FormField label="Name">
            <input
              className="field-input"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              required
            />
          </FormField>
          <FormField label="Description">
            <input
              className="field-input"
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            />
          </FormField>
          <FormField label="Icon">
            <div className="flex flex-wrap gap-2">
              {TASK_ICONS.map((icon) => (
                <button
                  key={icon}
                  type="button"
                  aria-label={icon}
                  aria-pressed={form.icon === icon}
                  className={`flex h-10 w-10 items-center justify-center rounded-xl border ${
                    form.icon === icon ? "border-primary bg-primary-light" : "border-border bg-surface"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, icon }))}
                >
                  <IconTile icon={icon} category={form.category} size={32} />
                </button>
              ))}
            </div>
          </FormField>
          <FormField label="Category">
            <div className="flex flex-wrap gap-2">
              {TASK_CATEGORIES.map((c) => (
                <button
                  key={c.id}
                  type="button"
                  aria-pressed={form.category === c.id}
                  className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                    form.category === c.id
                      ? "bg-primary text-white"
                      : "bg-surface text-ink-secondary"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, category: c.id }))}
                >
                  {c.label}
                </button>
              ))}
            </div>
          </FormField>
          <FormField label="Star value">
            <input
              className="field-input"
              type="number"
              min={1}
              value={form.pointValue}
              onChange={(e) =>
                setForm((f) => ({ ...f, pointValue: Number(e.target.value) || 0 }))
              }
            />
          </FormField>
          <FormField label="Recurrence">
            <div className="flex flex-wrap gap-2">
              {TASK_RECURRENCE_OPTIONS.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  aria-pressed={form.recurrence === r.id}
                  className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                    form.recurrence === r.id
                      ? "bg-primary text-white"
                      : "bg-surface text-ink-secondary"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, recurrence: r.id }))}
                >
                  {r.label}
                </button>
              ))}
            </div>
          </FormField>
          <FormField label="Approval">
            <select
              className="field-input"
              value={form.approvalBehavior}
              onChange={(e) =>
                setForm((f) => ({
                  ...f,
                  approvalBehavior: e.target.value as TaskApprovalBehavior,
                }))
              }
            >
              {TASK_APPROVAL_OPTIONS.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.label}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Assign to">
            {children.length === 0 ? (
              <p className="text-xs text-ink-tertiary">No kids yet — chore stays open to all.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  aria-pressed={form.assignedChildIds.length === 0}
                  className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                    form.assignedChildIds.length === 0
                      ? "bg-primary text-white"
                      : "bg-surface text-ink-secondary"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, assignedChildIds: [] }))}
                >
                  All kids
                </button>
                {children.map((c) => {
                  const on = form.assignedChildIds.includes(c.id);
                  return (
                    <button
                      key={c.id}
                      type="button"
                      aria-pressed={on}
                      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${
                        on ? "bg-primary text-white" : "bg-surface text-ink-secondary"
                      }`}
                      onClick={() => toggleAssigned(c.id)}
                    >
                      <ChildAvatar
                        emoji={c.avatar?.emoji}
                        colorHex={c.avatar?.colorHex}
                        photoURL={c.photoURL}
                        photoData={c.photoData}
                        size={18}
                        name={c.name}
                      />
                      {c.name}
                    </button>
                  );
                })}
              </div>
            )}
          </FormField>
          {formError ? (
            <p className="field-error" role="alert">
              {formError}
            </p>
          ) : null}
          <button className="btn-primary" type="submit" disabled={saving}>
            {saving ? "Saving…" : editingId ? "Save changes" : "Add chore"}
          </button>
        </form>
      </Modal>
    </div>
  );
}
