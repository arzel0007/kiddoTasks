"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendEmailVerification,
  signInWithEmailAndPassword,
} from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { firebaseAuth, firebaseFunctions, isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import { BrandLogo } from "@/components/brand-logo";
import { Modal } from "@/components/ui/modal";
import { canJoinWithCode, PREMIUM_PRICE } from "@/lib/entitlements";

type AuthMode = "signin" | "signup" | "join" | "kids";
type InfoKey = "how" | "pricing" | "summer";

const AUTH_TABS: { key: AuthMode; label: string; short: string }[] = [
  { key: "signin", label: "Sign in", short: "Sign in" },
  { key: "signup", label: "Create family", short: "Create" },
  { key: "join", label: "Join family", short: "Join" },
  { key: "kids", label: "Kids PIN", short: "Kids PIN" },
];

const AUTH_COPY: Record<AuthMode, { title: string; blurb: string; badge: string }> = {
  signin: {
    title: "Welcome back",
    blurb: "Sign in to manage missions and rewards.",
    badge: "Parent",
  },
  signup: {
    title: "Create your family",
    blurb: "Start free — free plan stays free.",
    badge: "Start free",
  },
  join: {
    title: "Join a family",
    blurb: `Enter a family code from another parent. Premium ${PREMIUM_PRICE.display}.`,
    badge: "Co-parent",
  },
  kids: {
    title: "Kids Station",
    blurb: "Enter the family PIN from a parent’s device.",
    badge: "PIN only",
  },
};

const STEPS = [
  {
    n: "1",
    title: "Add your family",
    body: "Kids, avatars, and a shared PIN — no kid email required.",
  },
  {
    n: "2",
    title: "Assign missions",
    body: "Daily or weekly chores with stars. Parent check-off when you want it.",
  },
  {
    n: "3",
    title: "Celebrate",
    body: "Stars, rewards, and play-together games for the whole crew.",
  },
];

const BENEFITS = [
  {
    title: "No kid email or bank account",
    body: "Family PIN only — kids open Kids Station without accounts.",
  },
  {
    title: "Free plan that stays free",
    body: "1 kid · 20 chores · stars, rewards, and games included.",
  },
  {
    title: `Premium ${PREMIUM_PRICE.display}`,
    body: "When you need co-parents or more kids. Not required to start.",
  },
  {
    title: "Web + iOS, same family",
    body: "Sign in on any device — missions and stars stay in sync.",
  },
];

const INFO_COPY: Record<InfoKey, { title: string; description?: string }> = {
  how: {
    title: "How Kiddotasks works",
    description: "Most families are up and running in a few minutes.",
  },
  pricing: {
    title: "Simple family pricing",
    description: "Free plan that stays free. Upgrade when you need co-parents or more kids.",
  },
  summer: {
    title: "Summer missions",
    description: "A light rhythm that still gets chores done.",
  },
};

function Field({
  label,
  children,
  error,
}: {
  label: string;
  children: React.ReactNode;
  error?: string | null;
}) {
  return (
    <div>
      <label className="field-label">{label}</label>
      {children}
      {error ? (
        <p className="field-error" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

export default function WelcomePage() {
  const router = useRouter();
  const loadFamily = useFamilyStore((s) => s.loadFamilyForParent);
  const [mode, setMode] = useState<AuthMode>("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [familyName, setFamilyName] = useState("Our family");
  const [parentName, setParentName] = useState("Parent");
  const [familyCode, setFamilyCode] = useState("");
  const [pin, setPin] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checkingSession, setCheckingSession] = useState(isFirebaseConfigured);
  /** Non-null when we need the user to click the email confirmation link. */
  const [pendingVerifyEmail, setPendingVerifyEmail] = useState<string | null>(null);
  const [resendNote, setResendNote] = useState<string | null>(null);
  const [infoModal, setInfoModal] = useState<InfoKey | null>(null);
  const [authOpen, setAuthOpen] = useState(false);

  const tabIndex = Math.max(
    0,
    AUTH_TABS.findIndex((t) => t.key === mode)
  );

  const submitLabel = useMemo(() => {
    if (busy) return "Please wait…";
    if (mode === "signin") return "Sign in";
    if (mode === "signup") return "Create family";
    if (mode === "join") return "Join family";
    return "Open Kids Station";
  }, [busy, mode]);

  function openAuth(next: AuthMode) {
    setMode(next);
    setError(null);
    setResendNote(null);
    setAuthOpen(true);
  }

  function closeAuth() {
    if (busy) return;
    setAuthOpen(false);
    setError(null);
  }

  function gmailUrl(addr: string) {
    return `https://mail.google.com/mail/u/0/#search/${encodeURIComponent(addr)}`;
  }

  async function sendVerification(user: { email?: string | null }) {
    try {
      await sendEmailVerification(user as never);
      setResendNote("Confirmation email sent.");
    } catch {
      setResendNote("Couldn’t send email — try again.");
    }
  }

  // Already signed in? Don't show the login form — go to Parent Center.
  useEffect(() => {
    if (!isFirebaseConfigured) {
      setCheckingSession(false);
      return;
    }
    const auth = firebaseAuth();
    const enterApp = async (user: { uid: string; email?: string | null; emailVerified: boolean }) => {
      if (!user.emailVerified) {
        setPendingVerifyEmail(user.email ?? "");
        setCheckingSession(false);
        return;
      }
      try {
        await loadFamily(user.uid);
        router.replace("/parent/today");
      } catch {
        setCheckingSession(false);
      }
    };
    if (auth.currentUser) {
      void enterApp(auth.currentUser);
    }
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        void enterApp(user);
      } else {
        // Wait a beat — session restore can emit null first.
        setTimeout(() => {
          if (!firebaseAuth().currentUser) setCheckingSession(false);
        }, 500);
      }
    });
    return () => unsub();
  }, [loadFamily, router]);

  async function handleAuth(e: React.FormEvent) {
    e.preventDefault();
    if (!isFirebaseConfigured) {
      setError("Set Firebase env vars in apps/web/.env.local first.");
      return;
    }
    setBusy(true);
    setError(null);
    setResendNote(null);
    try {
      const auth = firebaseAuth();
      if (mode === "signup") {
        const cred = await createUserWithEmailAndPassword(auth, email, password);
        await sendVerification(cred.user);
        const bootstrap = httpsCallable(firebaseFunctions(), "bootstrapFamily");
        await bootstrap({
          familyName,
          displayName: parentName,
          email,
        });
        setPendingVerifyEmail(email);
        return;
      } else if (mode === "signin") {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        if (!cred.user.emailVerified) {
          await sendVerification(cred.user);
          setPendingVerifyEmail(cred.user.email ?? email);
          return;
        }
        await loadFamily(cred.user.uid);
      } else if (mode === "join") {
        // Co-parent join is Premium; founder email always allowed (payments not live).
        const joinEmail = (email || firebaseAuth().currentUser?.email || "").trim();
        const joinAllowed = canJoinWithCode(
          joinEmail,
          useFamilyStore.getState().entitlements.plan !== "free"
        );
        if (!joinAllowed) {
          setError(
            `Joining another parent’s family with a code is Premium (${PREMIUM_PRICE.display}). See Plans.`
          );
          setBusy(false);
          return;
        }
        let cred;
        try {
          cred = await createUserWithEmailAndPassword(auth, email, password);
        } catch {
          cred = await signInWithEmailAndPassword(auth, email, password);
        }
        if (!cred.user.emailVerified) {
          await sendVerification(cred.user);
          setPendingVerifyEmail(cred.user.email ?? email);
          return;
        }
        const join = httpsCallable(firebaseFunctions(), "joinFamilyWithCode");
        await join({ familyCode: familyCode.trim().toUpperCase() });
        await loadFamily(cred.user.uid);
      } else if (mode === "kids") {
        const open = httpsCallable(firebaseFunctions(), "openKidsSession");
        const res = await open({ pin: pin.trim() });
        const data = res.data as {
          family: Record<string, unknown>;
          children: unknown[];
          tasks: unknown[];
          completions: unknown[];
          rewards: unknown[];
          claims: unknown[];
          transactions: unknown[];
          familyId: string;
        };
        const family = {
          ...(data.family as Record<string, unknown>),
          id: data.familyId,
        };
        useFamilyStore.getState().loadKidsSession({
          family: family as never,
          children: data.children as never,
          tasks: data.tasks as never,
          completions: data.completions as never,
          rewards: data.rewards as never,
          claims: data.claims as never,
          transactions: data.transactions as never,
        });
      }
      router.push(mode === "kids" ? "/kids" : "/parent/today");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setBusy(false);
    }
  }

  if (pendingVerifyEmail) {
    return (
      <main className="page-wash mx-auto flex min-h-screen w-full max-w-lg flex-col justify-center px-5 py-12 sm:px-6">
        <div className="card animate-rise text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-primary-light text-3xl">
            ✉️
          </div>
          <h1 className="text-2xl font-bold">Check your email</h1>
          <p className="mt-2 text-sm text-ink-secondary">
            We sent a confirmation link to:
          </p>
          <p className="mt-3 break-all rounded-xl bg-surface px-4 py-3 font-semibold">
            {pendingVerifyEmail}
          </p>
          <a
            className="btn-primary mt-5"
            href={gmailUrl(pendingVerifyEmail)}
            target="_blank"
            rel="noreferrer"
          >
            Open email
          </a>
          <ol className="mt-5 list-decimal space-y-1 pl-5 text-left text-sm text-ink-secondary">
            <li>Open your inbox</li>
            <li>Find the message from Kiddotasks</li>
            <li>Click the confirmation link</li>
            <li>Come back and sign in</li>
          </ol>
          <button
            type="button"
            className="btn-secondary mt-4"
            disabled={busy}
            onClick={async () => {
              const u = firebaseAuth().currentUser;
              if (u) {
                setBusy(true);
                await sendVerification(u);
                setBusy(false);
              } else {
                setResendNote("Sign in again to resend the email.");
              }
            }}
          >
            Resend confirmation email
          </button>
          {resendNote && (
            <p className="mt-2 text-xs text-ink-secondary">{resendNote}</p>
          )}
          <button
            type="button"
            className="btn-primary mt-4"
            disabled={busy}
            onClick={async () => {
              const u = firebaseAuth().currentUser;
              if (!u) {
                setPendingVerifyEmail(null);
                return;
              }
              setBusy(true);
              try {
                await u.reload();
                const fresh = firebaseAuth().currentUser;
                if (fresh?.emailVerified) {
                  await loadFamily(fresh.uid);
                  router.replace("/parent/today");
                } else {
                  setResendNote("Not confirmed yet — open the link in your email first.");
                }
              } catch {
                setResendNote("Couldn’t refresh — try again.");
              } finally {
                setBusy(false);
              }
            }}
          >
            I confirmed — continue
          </button>
          <button
            type="button"
            className="mt-4 text-sm font-semibold text-primary"
            onClick={async () => {
              await firebaseAuth().signOut();
              setPendingVerifyEmail(null);
              setResendNote(null);
            }}
          >
            ← Back to sign in
          </button>
        </div>
      </main>
    );
  }

  if (checkingSession) {
    return (
      <main className="page-wash mx-auto flex min-h-screen w-full max-w-lg flex-col items-center justify-center px-6">
        <BrandLogo size={72} />
        <p className="mt-4 text-sm text-ink-secondary">Signing you in…</p>
      </main>
    );
  }

  return (
    <div className="page-wash relative min-h-screen overflow-x-hidden">
      <div
        className="pattern-dots pointer-events-none absolute inset-x-0 top-0 h-[280px] opacity-60"
        aria-hidden="true"
      />

      {/* Header */}
      <header className="landing-header animate-rise">
        <div className="mx-auto flex w-full max-w-4xl flex-wrap items-center justify-between gap-x-3 gap-y-2 px-5 py-3 sm:px-8">
          <a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-2 focus:rounded-md focus:bg-surface-card focus:px-3 focus:py-2 focus:text-sm focus:font-semibold focus:text-primary">
            Skip to content
          </a>
          <div className="flex min-w-0 items-center gap-2.5">
            <BrandLogo size={40} />
            <div className="min-w-0">
              <p
                className="truncate text-lg font-bold tracking-tight"
                style={{ fontFamily: "ui-rounded, system-ui, sans-serif" }}
              >
                KiddoTasks
              </p>
              <p className="hidden text-xs font-medium text-primary sm:block">
                Missions for kids. Support for parents.
              </p>
            </div>
          </div>
          <nav aria-label="Account" className="flex items-center justify-end gap-1.5 sm:gap-2">
            <button
              type="button"
              className="chip-btn chip-btn--ghost"
              onClick={() => openAuth("join")}
            >
              Join
            </button>
            <button
              type="button"
              className="chip-btn chip-btn--ghost"
              onClick={() => openAuth("kids")}
            >
              Kids PIN
            </button>
            <button
              type="button"
              className="chip-btn"
              onClick={() => openAuth("signup")}
            >
              Create
            </button>
            <button
              type="button"
              className="chip-btn chip-btn--primary"
              onClick={() => openAuth("signin")}
            >
              Sign in
            </button>
          </nav>
        </div>
      </header>

      <main id="main" className="relative mx-auto w-full max-w-4xl px-5 pb-16 pt-8 sm:px-8 sm:pt-12">
        {/* Hero */}
        <section className="animate-rise delay-1 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center sm:hidden">
            <BrandLogo size={64} />
          </div>
          <h1
            className="text-3xl font-bold tracking-tight sm:text-4xl md:text-5xl"
            style={{ fontFamily: "ui-rounded, system-ui, sans-serif" }}
          >
            Family chores, made clear
          </h1>
          <p className="mx-auto mt-3 max-w-2xl text-base leading-relaxed text-ink-secondary sm:text-lg">
            Turn everyday chores into missions kids actually want to finish —
            with stars, rewards, and a calm Parent Center you can trust.
          </p>
          <div className="mt-4 flex flex-wrap items-center justify-center gap-2">
            <span className="trust-chip">No kid emails</span>
            <span className="trust-chip">No bank account</span>
            <span className="trust-chip">PIN login</span>
            <span className="trust-chip">Free plan stays free</span>
          </div>
        </section>

        {/* How it works */}
        <section className="animate-rise delay-2 mt-12" aria-labelledby="how-heading">
          <div className="mb-4 flex items-end justify-between gap-3">
            <div className="text-left">
              <p className="text-xs font-bold uppercase tracking-wider text-ink-tertiary">
                Three steps
              </p>
              <h2 id="how-heading" className="mt-1 text-xl font-bold tracking-tight sm:text-2xl">
                How it works
              </h2>
            </div>
            <button type="button" className="chip-btn shrink-0" onClick={() => setInfoModal("how")}>
              Details
            </button>
          </div>
          <ol className="grid gap-3 sm:grid-cols-3">
            {STEPS.map((step) => (
              <li key={step.n} className="step-card text-left">
                <div className="mb-2 flex items-center gap-2">
                  <span className="step-num" aria-hidden="true">
                    {step.n}
                  </span>
                  {step.n !== "3" && (
                    <span className="hidden text-ink-tertiary sm:inline" aria-hidden="true">
                      →
                    </span>
                  )}
                </div>
                <p className="text-sm font-bold">{step.title}</p>
                <p className="mt-1 text-xs leading-snug text-ink-secondary">{step.body}</p>
              </li>
            ))}
          </ol>
        </section>

        {/* Benefits */}
        <section className="animate-rise delay-3 card mt-8 text-left" aria-labelledby="benefits-heading">
          <h2 id="benefits-heading" className="text-lg font-bold tracking-tight">
            Built for real families
          </h2>
          <ul className="mt-2">
            {BENEFITS.map((b) => (
              <li key={b.title} className="feature-row">
                <span className="feature-check" aria-hidden="true">
                  ✓
                </span>
                <div>
                  <p className="text-sm font-semibold text-ink">{b.title}</p>
                  <p className="mt-0.5 text-xs leading-snug text-ink-secondary">{b.body}</p>
                </div>
              </li>
            ))}
          </ul>
          <div className="mt-4 flex flex-wrap gap-2">
            <button type="button" className="chip-btn" onClick={() => setInfoModal("how")}>
              How it works
            </button>
            <button type="button" className="chip-btn" onClick={() => setInfoModal("pricing")}>
              Pricing
            </button>
            <button type="button" className="chip-btn" onClick={() => setInfoModal("summer")}>
              Summer guide
            </button>
            <button type="button" className="chip-btn" onClick={() => openAuth("join")}>
              Join with code
            </button>
          </div>
          <p className="mt-3 text-xs text-ink-tertiary">
            Full pages still available at{" "}
            <Link href="/how-to" className="text-primary underline">
              /how-to
            </Link>
            ,{" "}
            <Link href="/pricing" className="text-primary underline">
              /pricing
            </Link>
            , and{" "}
            <Link href="/blog/summer-missions" className="text-primary underline">
              summer guide
            </Link>
            .
          </p>
        </section>

        {/* Bottom CTA */}
        <section className="animate-rise delay-4 mt-10 text-center">
          <p className="text-sm text-ink-secondary">Ready when your family is.</p>
          <button type="button" className="btn-primary mt-3 sm:w-auto sm:px-8" onClick={() => openAuth("signup")}>
            Create your family
          </button>
        </section>
      </main>

      {/* Auth modal */}
      <Modal
        open={authOpen}
        title={AUTH_COPY[mode].title}
        description={AUTH_COPY[mode].blurb}
        onClose={closeAuth}
      >
        <div className="mb-1 flex items-center justify-between gap-2">
          <span className="text-xs font-medium text-ink-tertiary">{AUTH_COPY[mode].badge}</span>
        </div>

        {!isFirebaseConfigured && (
          <p className="mb-4 rounded-xl bg-warning/15 p-3 text-sm text-ink" role="status">
            Firebase isn’t configured. Copy <code>.env.example</code> →{" "}
            <code>.env.local</code> and fill in your web app keys.
          </p>
        )}

        <div className="auth-segment mb-5" role="tablist" aria-label="Authentication">
          <div
            className="auth-segment__thumb"
            style={{ transform: `translateX(calc(${tabIndex} * (100% + 0.2rem)))` }}
            aria-hidden="true"
          />
          {AUTH_TABS.map((tab) => (
            <button
              key={tab.key}
              type="button"
              role="tab"
              id={`auth-tab-${tab.key}`}
              aria-selected={mode === tab.key}
              aria-controls="auth-panel"
              className={`auth-segment__btn ${mode === tab.key ? "is-active" : ""}`}
              onClick={() => {
                setMode(tab.key);
                setError(null);
              }}
            >
              {tab.short}
            </button>
          ))}
        </div>

        <div id="auth-panel" role="tabpanel" aria-labelledby={`auth-tab-${mode}`}>
          <form key={mode} onSubmit={handleAuth} className="form-swap space-y-3">
            {mode === "signup" && (
              <>
                <Field label="Family name">
                  <input
                    className="field-input"
                    value={familyName}
                    autoComplete="organization"
                    onChange={(e) => setFamilyName(e.target.value)}
                  />
                </Field>
                <Field label="Your name">
                  <input
                    className="field-input"
                    value={parentName}
                    autoComplete="name"
                    onChange={(e) => setParentName(e.target.value)}
                  />
                </Field>
              </>
            )}

            {mode === "join" && (
              <Field label="Family code">
                <input
                  className="field-input uppercase"
                  placeholder="KDO-XXXX"
                  value={familyCode}
                  autoCapitalize="characters"
                  autoComplete="off"
                  onChange={(e) => setFamilyCode(e.target.value)}
                />
              </Field>
            )}

            {mode === "kids" ? (
              <Field label="Family PIN" error={error}>
                <input
                  className="field-input"
                  inputMode="numeric"
                  placeholder="4–6 digits"
                  autoComplete="one-time-code"
                  aria-invalid={Boolean(error)}
                  value={pin}
                  onChange={(e) => setPin(e.target.value.replace(/\D/g, "").slice(0, 6))}
                />
              </Field>
            ) : (
              <>
                <Field label="Email">
                  <input
                    className="field-input"
                    type="email"
                    autoComplete="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </Field>
                <Field label="Password" error={mode === "signin" || mode === "signup" ? error : null}>
                  <input
                    className="field-input"
                    type="password"
                    autoComplete={mode === "signup" ? "new-password" : "current-password"}
                    aria-invalid={Boolean(error)}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </Field>
              </>
            )}

            {mode === "join" && error && (
              <p className="field-error" role="alert">
                {error}
              </p>
            )}

            <button className="btn-primary" type="submit" disabled={busy}>
              {busy && <span className="btn-spinner mr-2" aria-hidden="true" />}
              {submitLabel}
            </button>
          </form>
        </div>

        <p className="mt-5 text-center text-xs text-ink-tertiary">
          Same cloud family as the iOS app.{" "}
          <button
            type="button"
            className="font-semibold text-primary underline"
            onClick={() => {
              setAuthOpen(false);
              setInfoModal("pricing");
            }}
          >
            See plans
          </button>
        </p>
      </Modal>

      <Modal
        open={infoModal !== null}
        title={infoModal ? INFO_COPY[infoModal].title : ""}
        description={infoModal ? INFO_COPY[infoModal].description : undefined}
        onClose={() => setInfoModal(null)}
      >
        {infoModal === "how" && (
          <ol className="list-decimal space-y-4 pl-5">
            <li>
              <p className="font-bold text-ink">Create your family</p>
              <p>
                Sign up with email. Add your kids with names and avatars. Set a Kids PIN for
                the shared iPad.
              </p>
            </li>
            <li>
              <p className="font-bold text-ink">Assign missions</p>
              <p>Daily or weekly chores with stars. Approve when you want a parent check-off.</p>
            </li>
            <li>
              <p className="font-bold text-ink">Celebrate progress</p>
              <p>
                Kids see their own space, earn stars, unlock rewards — and play together in
                Games.
              </p>
            </li>
          </ol>
        )}
        {infoModal === "pricing" && (
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-border bg-surface p-4">
              <p className="font-bold text-ink">Free</p>
              <p className="mt-1 text-2xl font-bold text-ink">
                ₱0
                <span className="text-sm font-medium text-ink-secondary"> forever</span>
              </p>
              <ul className="mt-3 space-y-1.5 text-xs">
                <li>• 1 kid</li>
                <li>• Up to 20 chores</li>
                <li>• Kids Station (PIN login)</li>
                <li>• Stars &amp; rewards</li>
                <li>• No credit card required</li>
              </ul>
            </div>
            <div className="rounded-xl border-2 border-primary bg-surface p-4">
              <p className="font-bold text-primary">Premium</p>
              <p className="mt-1 text-2xl font-bold text-ink">
                {PREMIUM_PRICE.display.replace("/mo", "")}
                <span className="text-sm font-medium text-ink-secondary"> /month</span>
              </p>
              <ul className="mt-3 space-y-1.5 text-xs">
                <li>• Unlimited kids &amp; chores</li>
                <li>• Co-parent join with family code</li>
                <li>• Full history</li>
                <li>• Allowance modes</li>
                <li>• Week bonus celebrations</li>
              </ul>
            </div>
          </div>
        )}
        {infoModal === "summer" && (
          <div className="space-y-3">
            <p>
              Keep a light daily rhythm: one morning mission, one outdoor job, and a reward
              the kids chose. Short lists beat long checklists.
            </p>
            <ul className="list-disc space-y-2 pl-5">
              <li>Outdoor: water plants, wipe table after lunch, tidy shoes.</li>
              <li>Swap 20 minutes of screens for a quick mission when energy is high.</li>
              <li>Use week bonus (e.g. “movie night”) when all seven days have progress.</li>
            </ul>
          </div>
        )}
        <div className="mt-5 flex justify-end">
          <button type="button" className="btn-secondary w-auto px-5" onClick={() => setInfoModal(null)}>
            Got it
          </button>
        </div>
      </Modal>
    </div>
  );
}
