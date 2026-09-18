"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { IconTile } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";
import { Modal } from "@/components/ui/modal";
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

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="field-label">{label}</label>
      {children}
    </div>
  );
}

export default function TasksPage() {
  const {
    tasks,
    children,
    loading,
    parentEmail,
    entitlements,
    addTask,
    updateTask,
    setTaskActive,
  } = useFamilyStore();
  const [search, setSearch] = useState("");
  const [showArchived, setShowArchived] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<TaskForm>(emptyForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const premium = entitlements.plan === "plus" || entitlements.plan === "pro";
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

  return (
    <div className="space-y-4">
      <div className="relative">
        <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-secondary">
          🔍
        </span>
        <input
          className="field-input pl-9 pr-9"
          placeholder="Search chores…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        {search ? (
          <button
            type="button"
            aria-label="Clear search"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full px-2 py-1 text-sm text-ink-tertiary hover:text-ink"
            onClick={() => setSearch("")}
          >
            ✕
          </button>
        ) : null}
      </div>

      <div className="card">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <h2 className="font-bold">{showArchived ? "Archived chores" : "Active chores"}</h2>
            <button
              type="button"
              className="text-xs font-semibold text-primary underline"
              onClick={() => setShowArchived((v) => !v)}
            >
              {showArchived ? "Show active" : "Show archived"}
            </button>
          </div>
          <button type="button" className="chip-btn chip-btn--primary" onClick={openCreate}>
            + Add chore
          </button>
        </div>
        {loading ? (
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
          <ul className="divide-y divide-border">
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
          <Field label="Name">
            <input
              className="field-input"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              required
            />
          </Field>
          <Field label="Description">
            <input
              className="field-input"
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            />
          </Field>
          <Field label="Icon">
            <div className="flex flex-wrap gap-2">
              {TASK_ICONS.map((icon) => (
                <button
                  key={icon}
                  type="button"
                  aria-label={icon}
                  className={`flex h-10 w-10 items-center justify-center rounded-xl border ${
                    form.icon === icon ? "border-primary bg-primary-light" : "border-border bg-surface"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, icon }))}
                >
                  <IconTile icon={icon} category={form.category} size={32} />
                </button>
              ))}
            </div>
          </Field>
          <Field label="Category">
            <div className="flex flex-wrap gap-2">
              {TASK_CATEGORIES.map((c) => (
                <button
                  key={c.id}
                  type="button"
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
          </Field>
          <Field label="Star value">
            <input
              className="field-input"
              type="number"
              min={1}
              value={form.pointValue}
              onChange={(e) =>
                setForm((f) => ({ ...f, pointValue: Number(e.target.value) || 0 }))
              }
            />
          </Field>
          <Field label="Recurrence">
            <div className="flex flex-wrap gap-2">
              {TASK_RECURRENCE_OPTIONS.map((r) => (
                <button
                  key={r.id}
                  type="button"
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
          </Field>
          <Field label="Approval">
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
          </Field>
          <Field label="Assign to">
            {children.length === 0 ? (
              <p className="text-xs text-ink-tertiary">No kids yet — chore stays open to all.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
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
                      className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                        on ? "bg-primary text-white" : "bg-surface text-ink-secondary"
                      }`}
                      onClick={() => toggleAssigned(c.id)}
                    >
                      {c.avatar?.emoji} {c.name}
                    </button>
                  );
                })}
              </div>
            )}
          </Field>
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
