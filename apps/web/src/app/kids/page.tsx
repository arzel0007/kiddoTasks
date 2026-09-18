"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { onAuthStateChanged, signInWithEmailAndPassword } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import {
  firebaseAuth,
  firebaseFunctions,
  isFirebaseConfigured,
} from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import type {
  Child,
  Family,
  KiddoTask,
  PointTransaction,
  Reward,
  RewardClaim,
  TaskCompletion,
  WishlistItem,
} from "@/lib/types";
import { ChildAvatar, IconTile, sfSymbolToGlyph } from "@/lib/ui";
import { SkeletonPlayerGrid } from "@/components/skeleton";
import { ArzAvatar, arzHandle } from "@/components/arz-companion";
import { toast } from "@/components/toast";
import { errorMessage } from "@/lib/errors";
import { Modal } from "@/components/ui/modal";
import {
  WISHLIST_STATUS_LABELS,
  occasionLabel,
  wishlistStatusBadgeClass,
} from "@/lib/wishlist";

type UnlockTab = "pin" | "parent";

type KidsSessionPayload = {
  family: Family;
  children: Child[];
  tasks: KiddoTask[];
  completions: TaskCompletion[];
  rewards: Reward[];
  claims: RewardClaim[];
  transactions: PointTransaction[];
  wishlistItems?: WishlistItem[];
  kidsAccessToken?: string | null;
  wishlistEnabled?: boolean;
};

type WishlistForm = {
  title: string;
  message: string;
  occasion: string | null;
};

const emptyWishlistForm: WishlistForm = { title: "", message: "", occasion: null };

/**
 * Kids Station — parent-signed-in browser or family PIN.
 * Unlock stays on this route so auth never bounces through Parent Today.
 */
export default function KidsPage() {
  const router = useRouter();
  const store = useFamilyStore();
  const { family, children, tasks, completions } = store;
  const [selectedChildId, setSelectedChildId] = useState<string | null>(null);
  const [restoringParent, setRestoringParent] = useState(
    () => isFirebaseConfigured && !store.kidsMode && !store.family
  );

  const [unlockTab, setUnlockTab] = useState<UnlockTab>("pin");
  const [pin, setPin] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [unlockError, setUnlockError] = useState<string | null>(null);

  // Wishlist UI state
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingItemId, setEditingItemId] = useState<string | null>(null);
  const [wishForm, setWishForm] = useState<WishlistForm>(emptyWishlistForm);
  const [wishFormError, setWishFormError] = useState<string | null>(null);
  const [wishBusyId, setWishBusyId] = useState<string | null>(null);
  const [wishSaving, setWishSaving] = useState(false);
  const [pendingWishDelete, setPendingWishDelete] = useState<string | null>(null);

  const canOpen = Boolean(family) || store.kidsMode;
  const selected = children.find((c) => c.id === selectedChildId) ?? null;
  const wishlistEnabled = store.wishlistEnabled === true;

  const myWishlist = useMemo(() => {
    if (!selected) return [] as WishlistItem[];
    // RECEIVED is model-only — hide in kids UI.
    return store.wishlistItems.filter(
      (w) => w.childId === selected.id && w.status !== "RECEIVED"
    );
  }, [store.wishlistItems, selected]);

  // Parent session can outlive this route — restore family so a signed-in
  // parent opens Kids Station instead of the lock screen.
  useEffect(() => {
    if (!isFirebaseConfigured) {
      setRestoringParent(false);
      return;
    }
    const auth = firebaseAuth();
    let cancelled = false;
    const tryLoad = (user: { uid: string } | null) => {
      if (cancelled) return;
      if (!user) {
        setRestoringParent(false);
        return;
      }
      const s = useFamilyStore.getState();
      if (s.kidsMode || s.family || s.loading) {
        setRestoringParent(false);
        return;
      }
      void s.loadFamilyForParent(user.uid).finally(() => {
        if (!cancelled) setRestoringParent(false);
      });
    };
    tryLoad(auth.currentUser);
    const unsub = onAuthStateChanged(auth, tryLoad);
    return () => {
      cancelled = true;
      unsub();
    };
  }, []);

  useEffect(() => {
    if (canOpen) arzHandle("kidsStationOpened");
  }, [canOpen]);

  const missions = useMemo(() => {
    if (!selected) return [];
    return tasks.filter(
      (t) =>
        t.isActive &&
        (t.assignedChildIds.length === 0 || t.assignedChildIds.includes(selected.id))
    );
  }, [tasks, selected]);

  async function unlockWithPin(e: React.FormEvent) {
    e.preventDefault();
    if (!isFirebaseConfigured) {
      const msg = "Firebase isn’t configured.";
      setUnlockError(msg);
      toast.error(msg);
      return;
    }
    const value = pin.trim();
    if (!/^\d{4,6}$/.test(value)) {
      const msg = "Enter the family PIN (4–6 digits).";
      setUnlockError(msg);
      toast.error(msg);
      return;
    }
    setBusy(true);
    setUnlockError(null);
    try {
      const open = httpsCallable(firebaseFunctions(), "openKidsSession");
      const res = await open({ pin: value });
      const data = res.data as {
        family: Record<string, unknown>;
        children: unknown[];
        tasks: unknown[];
        completions: unknown[];
        rewards: unknown[];
        claims: unknown[];
        transactions: unknown[];
        wishlistItems?: unknown[];
        wishlistEnabled?: boolean;
        kidsAccessToken?: string | null;
        familyId: string;
      };
      const payload = {
        family: { ...(data.family as Record<string, unknown>), id: data.familyId },
        children: data.children,
        tasks: data.tasks,
        completions: data.completions,
        rewards: data.rewards,
        claims: data.claims,
        transactions: data.transactions,
        wishlistItems: (data.wishlistItems ?? []) as WishlistItem[],
        kidsAccessToken: data.kidsAccessToken ?? null,
        wishlistEnabled: data.wishlistEnabled === true,
      } as unknown as KidsSessionPayload;
      useFamilyStore.getState().loadKidsSession(payload);
      setPin("");
      setSelectedChildId(null);
      toast.success("Kids Station unlocked. Have fun!");
    } catch (err) {
      const msg = errorMessage(err, "Wrong PIN — try again.");
      setUnlockError(msg);
      toast.error(msg);
    } finally {
      setBusy(false);
    }
  }

  async function unlockWithParent(e: React.FormEvent) {
    e.preventDefault();
    if (!isFirebaseConfigured) {
      const msg = "Firebase isn’t configured.";
      setUnlockError(msg);
      toast.error(msg);
      return;
    }
    setBusy(true);
    setUnlockError(null);
    try {
      const auth = firebaseAuth();
      const cred = await signInWithEmailAndPassword(auth, email.trim(), password);
      if (!cred.user.emailVerified) {
        const msg = "Confirm your parent email first, then try again.";
        setUnlockError(msg);
        toast.error(msg);
        return;
      }
      await useFamilyStore.getState().loadFamilyForParent(cred.user.uid);
      const after = useFamilyStore.getState();
      if (!after.family) {
        const msg = after.error || "Couldn’t load this family.";
        setUnlockError(msg);
        toast.error(msg);
        return;
      }
      setPassword("");
      setSelectedChildId(null);
      toast.success("Signed in — Kids Station is ready.");
    } catch (err) {
      const msg = errorMessage(err, "Sign in failed.");
      setUnlockError(msg);
      toast.error(msg);
    } finally {
      setBusy(false);
    }
  }

  function startAddWish() {
    setEditingItemId(null);
    setWishForm(emptyWishlistForm);
    setWishFormError(null);
    setShowAddForm(true);
  }

  function startEditWish(item: WishlistItem) {
    setEditingItemId(item.id);
    setWishForm({
      title: item.title,
      message: item.message ?? "",
      occasion: item.occasion ? String(item.occasion) : null,
    });
    setWishFormError(null);
    setShowAddForm(true);
  }

  async function saveWish(e: React.FormEvent) {
    e.preventDefault();
    if (!selected) {
      const msg = "Pick who you are first.";
      setWishFormError(msg);
      toast.error(msg);
      return;
    }
    const title = wishForm.title.trim();
    if (!title) {
      const msg = "What do you wish for?";
      setWishFormError(msg);
      toast.error(msg);
      return;
    }
    setWishSaving(true);
    setWishFormError(null);
    try {
      if (editingItemId) {
        const existing = store.wishlistItems.find((w) => w.id === editingItemId);
        await store.updateWishlistItem({
          itemId: editingItemId,
          title,
          message: wishForm.message,
          occasion: wishForm.occasion,
          version: existing?.version,
        });
        toast.success("Wishlist updated!");
      } else {
        await store.addWishlistItem({
          childId: selected.id,
          title,
          message: wishForm.message,
          occasion: wishForm.occasion,
        });
        toast.success("Added to your wishlist!");
      }
      setShowAddForm(false);
      setEditingItemId(null);
      setWishForm(emptyWishlistForm);
    } catch (err) {
      const msg = errorMessage(err, "Couldn’t save wishlist item.");
      setWishFormError(msg);
      toast.error(msg);
    } finally {
      setWishSaving(false);
    }
  }

  async function deleteWish(itemId: string) {
    setWishBusyId(itemId);
    try {
      await store.deleteWishlistItem(itemId);
      setPendingWishDelete(null);
      if (editingItemId === itemId) {
        setShowAddForm(false);
        setEditingItemId(null);
      }
      toast.success("Removed from your wishlist.");
    } catch (err) {
      toast.error(errorMessage(err, "Couldn’t delete wishlist item."));
    } finally {
      setWishBusyId(null);
    }
  }

  if ((store.loading || restoringParent) && !family && !store.kidsMode) {
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
      <main className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-6 py-10 text-center">
        <div className="card w-full">
          <p className="text-5xl">🔒</p>
          <h1 className="mt-3 text-2xl font-bold">Kids Station</h1>
          <p className="mt-2 text-sm text-ink-secondary">
            Unlock with the family PIN, or sign in as a parent.
          </p>

          <div className="auth-segment mx-auto mb-5 mt-5" role="tablist" aria-label="Unlock">
            <button
              type="button"
              role="tab"
              aria-selected={unlockTab === "pin"}
              className={`auth-segment__btn ${unlockTab === "pin" ? "is-active" : ""}`}
              onClick={() => {
                setUnlockTab("pin");
                setUnlockError(null);
              }}
            >
              Family PIN
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={unlockTab === "parent"}
              className={`auth-segment__btn ${unlockTab === "parent" ? "is-active" : ""}`}
              onClick={() => {
                setUnlockTab("parent");
                setUnlockError(null);
              }}
            >
              Parent sign in
            </button>
          </div>

          {unlockTab === "pin" ? (
            <form onSubmit={unlockWithPin} className="space-y-3 text-left">
              <div>
                <label className="field-label" htmlFor="kids-station-pin">
                  Family PIN
                </label>
                <input
                  id="kids-station-pin"
                  className="field-input"
                  inputMode="numeric"
                  placeholder="4–6 digits"
                  autoComplete="one-time-code"
                  value={pin}
                  onChange={(e) => setPin(e.target.value.replace(/\D/g, "").slice(0, 6))}
                  aria-invalid={Boolean(unlockError)}
                />
              </div>
              {unlockError ? (
                <p className="field-error text-left" role="alert">
                  {unlockError}
                </p>
              ) : null}
              <button className="btn-primary w-full" type="submit" disabled={busy}>
                {busy && <span className="btn-spinner mr-2" aria-hidden="true" />}
                Open Kids Station
              </button>
            </form>
          ) : (
            <form onSubmit={unlockWithParent} className="space-y-3 text-left">
              <div>
                <label className="field-label" htmlFor="kids-station-email">
                  Parent email
                </label>
                <input
                  id="kids-station-email"
                  className="field-input"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              <div>
                <label className="field-label" htmlFor="kids-station-password">
                  Password
                </label>
                <input
                  id="kids-station-password"
                  className="field-input"
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  aria-invalid={Boolean(unlockError)}
                />
              </div>
              {unlockError ? (
                <p className="field-error text-left" role="alert">
                  {unlockError}
                </p>
              ) : null}
              <button className="btn-primary w-full" type="submit" disabled={busy}>
                {busy && <span className="btn-spinner mr-2" aria-hidden="true" />}
                Open Kids Station
              </button>
            </form>
          )}

          <p className="mt-5 text-xs text-ink-tertiary">
            Need the full parent app?{" "}
            <button
              type="button"
              className="font-semibold text-primary underline"
              onClick={() => router.push("/")}
            >
              Go to Parent Center
            </button>
          </p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-page pb-28">
      <div className="mx-auto max-w-3xl px-4 py-6">
        {/* Top bar — Arz inline with title (flat). mb-5 keeps gap before content. */}
        <div className="mb-5 flex min-h-[96px] items-center gap-3">
          <Link
            href={store.parentUid ? "/parent/today" : "/"}
            className="rounded-full bg-white/80 px-3 py-1.5 text-xs font-bold text-ink-secondary shadow-card"
          >
            Parent
          </Link>
          <ArzAvatar kidName={selected?.name ?? children[0]?.name ?? "friend"} />
          <h1 className="min-w-0 flex-1 truncate text-2xl font-bold text-ink">
            {selected ? `Hi, ${selected.name}!` : "Who's playing?"}
          </h1>
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
                    className="card flex flex-col items-center gap-3 py-7 transition hover:-translate-y-0.5"
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

            {/* Wishlist — separate domain from points. selected childId required. */}
            <section className="mt-6 card" aria-label="Wishlist">
              <div className="mb-3 flex items-center justify-between gap-2">
                <h2 className="font-bold">🎁 Wishlist</h2>
                {wishlistEnabled ? (
                  !showAddForm ? (
                    <button
                      type="button"
                      className="chip-btn chip-btn--primary"
                      onClick={startAddWish}
                    >
                      + Add wish
                    </button>
                  ) : null
                ) : null}
              </div>

              {!wishlistEnabled ? (
                <div className="rounded-xl bg-surface p-3 text-sm text-ink-secondary">
                  <p className="font-semibold">🔒 Wishlist is locked</p>
                  <p className="mt-1">
                    Ask a parent to turn on Wishlist in Family settings.
                  </p>
                  {myWishlist.length > 0 ? (
                    <p className="mt-2 text-xs text-ink-tertiary">
                      Past wishes stay here until a parent manages them.
                    </p>
                  ) : null}
                </div>
              ) : null}

              {wishlistEnabled && showAddForm ? (
                <form onSubmit={saveWish} className="mb-4 space-y-3 rounded-card border border-border p-3">
                  <div>
                    <label className="field-label" htmlFor="wish-title">
                      I wish for…
                    </label>
                    <input
                      id="wish-title"
                      className="field-input"
                      required
                      maxLength={120}
                      placeholder="A blue bicycle"
                      value={wishForm.title}
                      onChange={(e) =>
                        setWishForm((f) => ({ ...f, title: e.target.value }))
                      }
                    />
                  </div>
                  <div>
                    <label className="field-label" htmlFor="wish-message">
                      Why I want it (optional)
                    </label>
                    <input
                      id="wish-message"
                      className="field-input"
                      maxLength={500}
                      placeholder="So we can ride to the park"
                      value={wishForm.message}
                      onChange={(e) =>
                        setWishForm((f) => ({ ...f, message: e.target.value }))
                      }
                    />
                  </div>
                  {wishFormError ? (
                    <p className="field-error" role="alert">
                      {wishFormError}
                    </p>
                  ) : null}
                  <div className="flex flex-wrap gap-2">
                    <button className="btn-primary" type="submit" disabled={wishSaving}>
                      {wishSaving
                        ? "Saving…"
                        : editingItemId
                          ? "Save changes"
                          : "Add to wishlist"}
                    </button>
                    <button
                      type="button"
                      className="btn-secondary"
                      disabled={wishSaving}
                      onClick={() => {
                        setShowAddForm(false);
                        setEditingItemId(null);
                        setWishFormError(null);
                      }}
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              ) : null}

              {myWishlist.length === 0 ? (
                <div className="text-center">
                  <p className="text-3xl">🎁</p>
                  <p className="mt-2 font-semibold">No wishes yet</p>
                  <p className="text-sm text-ink-secondary">
                    {wishlistEnabled
                      ? "Add something you’d love to get."
                      : "Wishes will show up here when the wishlist is on."}
                  </p>
                </div>
              ) : (
                <ul className="space-y-3">
                  {myWishlist.map((item) => {
                    const canEdit = item.status === "PENDING";
                    const canDelete =
                      item.status === "PENDING" || item.status === "REJECTED";
                    const showResponse =
                      (item.status === "APPROVED" || item.status === "REJECTED") &&
                      Boolean(item.parentResponse);
                    return (
                      <li
                        key={item.id}
                        className={`rounded-card border border-border p-3 ${
                          item.status === "REJECTED" ? "opacity-80" : ""
                        }`}
                      >
                        <div className="flex flex-wrap items-start justify-between gap-2">
                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className={wishlistStatusBadgeClass(item.status)}>
                                {WISHLIST_STATUS_LABELS[item.status] ?? item.status}
                              </span>
                              {item.occasion ? (
                                <span className="rounded-pill bg-surface px-2.5 py-1 text-xs font-semibold text-ink-secondary">
                                  {occasionLabel(item.occasion)}
                                </span>
                              ) : null}
                            </div>
                            <p className="mt-1 truncate font-bold">{item.title}</p>
                            {item.message ? (
                              <p className="text-sm text-ink-secondary">{item.message}</p>
                            ) : null}
                            {showResponse ? (
                              <p className="mt-1 text-sm italic text-ink-secondary">
                                Parent: {item.parentResponse}
                              </p>
                            ) : null}
                          </div>
                          {wishlistEnabled && (canEdit || canDelete) ? (
                            <div className="flex shrink-0 flex-wrap gap-1.5">
                              {canEdit ? (
                                <button
                                  type="button"
                                  className="btn-secondary btn-compact"
                                  disabled={wishBusyId === item.id}
                                  onClick={() => startEditWish(item)}
                                >
                                  Edit
                                </button>
                              ) : null}
                              {canDelete ? (
                                <button
                                  type="button"
                                  className="btn-secondary btn-compact !text-attention"
                                  disabled={wishBusyId === item.id}
                                  onClick={() => setPendingWishDelete(item.id)}
                                >
                                  {wishBusyId === item.id ? "…" : "Delete"}
                                </button>
                              ) : null}
                            </div>
                          ) : null}
                        </div>
                      </li>
                    );
                  })}
                </ul>
              )}
            </section>
          </div>
        )}
      </div>

      <Modal
        open={pendingWishDelete !== null}
        title="Remove this wish?"
        description="It will disappear from your wishlist."
        onClose={() => setPendingWishDelete(null)}
      >
        <div className="mt-2 space-y-2">
          <button
            type="button"
            className="btn-primary"
            disabled={wishBusyId === pendingWishDelete}
            onClick={() =>
              pendingWishDelete && void deleteWish(pendingWishDelete)
            }
          >
            {wishBusyId === pendingWishDelete ? "Removing…" : "Remove"}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={() => setPendingWishDelete(null)}
          >
            Cancel
          </button>
        </div>
      </Modal>
    </main>
  );
}
