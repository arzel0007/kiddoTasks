"use client";

import { useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { IconTile, ChildAvatar } from "@/lib/ui";
import { SkeletonListRow } from "@/components/skeleton";
import { Modal } from "@/components/ui/modal";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import { REWARD_ICONS } from "@/lib/catalog";
import type { Reward } from "@/lib/types";

type RewardForm = {
  name: string;
  description: string;
  icon: string;
  pointCost: number;
  eligibleChildIds: string[];
  requiresApproval: boolean;
};

const emptyForm: RewardForm = {
  name: "",
  description: "",
  icon: "gift.fill",
  pointCost: 20,
  eligibleChildIds: [],
  requiresApproval: true,
};

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="field-label">{label}</label>
      {children}
    </div>
  );
}

export default function RewardsPage() {
  const {
    rewards,
    children,
    loading,
    error,
    setRewardActive,
    removeReward,
    addReward,
    updateReward,
  } = useFamilyStore();
  const [pendingDelete, setPendingDelete] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<RewardForm>(emptyForm);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const active = rewards.filter((r) => r.isActive);
  const archived = rewards.filter((r) => !r.isActive);

  function openCreate() {
    setEditingId(null);
    setForm(emptyForm);
    setFormError(null);
    setEditorOpen(true);
  }

  function openEdit(reward: Reward) {
    setEditingId(reward.id);
    setForm({
      name: reward.name,
      description: reward.description ?? "",
      icon: reward.icon || "gift.fill",
      pointCost: reward.pointCost,
      eligibleChildIds: reward.eligibleChildIds ?? [],
      requiresApproval: reward.requiresApproval ?? true,
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
        pointCost: form.pointCost,
        eligibleChildIds: form.eligibleChildIds,
        requiresApproval: form.requiresApproval,
      };
      if (editingId) {
        await updateReward(editingId, payload);
        toast.success(`Updated “${payload.name.trim()}”.`);
      } else {
        await addReward(payload);
        toast.success(`Added “${payload.name.trim()}”.`);
      }
      setEditorOpen(false);
    } catch (err) {
      const msg = errorMessage(err, "Couldn’t save reward.");
      setFormError(msg);
      toast.error(msg);
    } finally {
      setSaving(false);
    }
  }

  async function archiveReward(id: string, name: string) {
    setBusyId(id);
    try {
      await setRewardActive(id, false);
      toast.success(`Archived “${name}”.`);
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t archive reward."));
    } finally {
      setBusyId(null);
    }
  }

  async function restoreReward(id: string, name: string) {
    setBusyId(id);
    try {
      await setRewardActive(id, true);
      toast.success(`Restored “${name}”.`);
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t restore reward."));
    } finally {
      setBusyId(null);
    }
  }

  async function deleteReward(id: string) {
    const reward = rewards.find((r) => r.id === id);
    if (!reward) {
      toast.error("Couldn’t find that reward.");
      return;
    }
    setBusyId(id);
    try {
      await removeReward(id);
      setPendingDelete(null);
      toast.success(`Deleted “${reward.name}”.`);
    } catch (e) {
      toast.error(errorMessage(e, "Couldn’t delete reward."));
    } finally {
      setBusyId(null);
    }
  }

  function toggleEligible(childId: string) {
    setForm((f) => ({
      ...f,
      eligibleChildIds: f.eligibleChildIds.includes(childId)
        ? f.eligibleChildIds.filter((id) => id !== childId)
        : [...f.eligibleChildIds, childId],
    }));
  }

  return (
    <div className="space-y-4">
      {error ? (
        <div className="card border-error/40">
          <p className="font-semibold text-error">{error}</p>
        </div>
      ) : null}
      <div className="card">
        <div className="mb-3 flex items-center justify-between gap-2">
          <h2 className="font-bold">Active rewards</h2>
          <button type="button" className="chip-btn chip-btn--primary" onClick={openCreate}>
            + Add reward
          </button>
        </div>
        {loading ? (
          <div className="space-y-3">
            <SkeletonListRow />
            <SkeletonListRow />
          </div>
        ) : active.length === 0 ? (
          <div className="text-center">
            <p className="text-sm text-ink-secondary">No rewards yet. Kids can shop once you add some.</p>
            <button type="button" className="btn-secondary mt-3 inline-flex w-auto px-4" onClick={openCreate}>
              Add reward
            </button>
          </div>
        ) : (
          <ul className="grid gap-3 sm:grid-cols-2">
            {active.map((r) => (
              <li
                key={r.id}
                className="flex items-start gap-3 rounded-card border border-border p-3"
              >
                <IconTile icon={r.icon} reward size={48} />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-semibold">{r.name}</p>
                      {r.description ? (
                        <p className="text-sm text-ink-secondary line-clamp-2">{r.description}</p>
                      ) : null}
                      <p className="mt-1 text-sm font-bold text-primary">★ {r.pointCost}</p>
                    </div>
                    <div className="flex shrink-0 flex-wrap gap-1.5">
                      <button
                        type="button"
                        className="btn-secondary btn-compact"
                        disabled={busyId === r.id}
                        onClick={() => openEdit(r)}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className="btn-secondary btn-compact"
                        disabled={busyId === r.id}
                        onClick={() => void archiveReward(r.id, r.name)}
                      >
                        {busyId === r.id ? "…" : "Archive"}
                      </button>
                      <button
                        type="button"
                        className="btn-secondary btn-compact !text-attention"
                        disabled={busyId === r.id}
                        onClick={() => setPendingDelete(r.id)}
                      >
                        Delete
                      </button>
                    </div>
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
                  <p className="text-xs text-ink-tertiary">Archived · ★ {r.pointCost}</p>
                </div>
                <div className="flex shrink-0 gap-1.5">
                  <button
                    type="button"
                    className="btn-secondary btn-compact"
                    disabled={busyId === r.id}
                    onClick={() => openEdit(r)}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className="btn-secondary btn-compact"
                    disabled={busyId === r.id}
                    onClick={() => void restoreReward(r.id, r.name)}
                  >
                    {busyId === r.id ? "…" : "Restore"}
                  </button>
                  <button
                    type="button"
                    className="btn-secondary btn-compact !text-attention"
                    disabled={busyId === r.id}
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

      <Modal
        open={editorOpen}
        title={editingId ? "Edit reward" : "Add reward"}
        description="Kids claim these with stars in Kids Station."
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
              {REWARD_ICONS.map((icon) => (
                <button
                  key={icon}
                  type="button"
                  aria-label={icon}
                  className={`flex h-10 w-10 items-center justify-center rounded-xl border text-lg ${
                    form.icon === icon ? "border-primary bg-primary-light" : "border-border bg-surface"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, icon }))}
                >
                  <IconTile icon={icon} reward size={32} />
                </button>
              ))}
            </div>
          </Field>
          <Field label="Star cost">
            <input
              className="field-input"
              type="number"
              min={1}
              value={form.pointCost}
              onChange={(e) =>
                setForm((f) => ({ ...f, pointCost: Number(e.target.value) || 0 }))
              }
            />
          </Field>
          <Field label="Eligible kids">
            {children.length === 0 ? (
              <p className="text-xs text-ink-tertiary">No kids yet — reward stays open to all.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                    form.eligibleChildIds.length === 0
                      ? "bg-primary text-white"
                      : "bg-surface text-ink-secondary"
                  }`}
                  onClick={() => setForm((f) => ({ ...f, eligibleChildIds: [] }))}
                >
                  All kids
                </button>
                {children.map((c) => {
                  const on = form.eligibleChildIds.includes(c.id);
                  return (
                    <button
                      key={c.id}
                      type="button"
                      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${
                        on ? "bg-primary text-white" : "bg-surface text-ink-secondary"
                      }`}
                      onClick={() => toggleEligible(c.id)}
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
          </Field>
          <label className="flex items-center gap-2 text-sm font-medium text-ink">
            <input
              type="checkbox"
              checked={form.requiresApproval}
              onChange={(e) =>
                setForm((f) => ({ ...f, requiresApproval: e.target.checked }))
              }
            />
            Parent approval required
          </label>
          {formError ? (
            <p className="field-error" role="alert">
              {formError}
            </p>
          ) : null}
          <button className="btn-primary" type="submit" disabled={saving}>
            {saving ? "Saving…" : editingId ? "Save changes" : "Add reward"}
          </button>
        </form>
      </Modal>

      <Modal
        open={pendingDelete !== null}
        title="Delete this reward?"
        description="Kids can no longer claim it. This removes it from the cloud."
        onClose={() => setPendingDelete(null)}
      >
        <div className="mt-2 space-y-2">
          <button
            type="button"
            className="btn-primary"
            disabled={busyId === pendingDelete}
            onClick={() => pendingDelete && void deleteReward(pendingDelete)}
          >
            {busyId === pendingDelete ? "Deleting…" : "Delete"}
          </button>
          <button type="button" className="btn-secondary" onClick={() => setPendingDelete(null)}>
            Cancel
          </button>
        </div>
      </Modal>
    </div>
  );
}
