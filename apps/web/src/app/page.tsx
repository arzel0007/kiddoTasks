"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
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
import { canJoinWithCode, isOwnerEmail, PREMIUM_PRICE } from "@/lib/entitlements";

export default function WelcomePage() {
  const router = useRouter();
  const loadFamily = useFamilyStore((s) => s.loadFamilyForParent);
  const [mode, setMode] = useState<"signin" | "signup" | "join" | "kids">("signin");
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
        // Co-parent join is Premium (founder email always allowed).
        const joinAllowed = canJoinWithCode(
          email || firebaseAuth().currentUser?.email,
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
      <main className="mx-auto flex min-h-screen w-full max-w-lg flex-col justify-center px-6 py-12">
        <div className="card text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-primary-light text-3xl">
            ✉️
          </div>
          <h1 className="text-2xl font-bold">Check your email</h1>
          <p className="mt-2 text-sm text-ink-secondary">
            We sent a confirmation link to:
          </p>
          <p className="mt-3 rounded-xl bg-surface px-4 py-3 font-semibold">
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
      <main className="mx-auto flex min-h-screen w-full max-w-lg flex-col items-center justify-center px-6">
        <BrandLogo size={72} />
        <p className="mt-4 text-sm text-ink-secondary">Signing you in…</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-lg flex-col justify-center px-6 py-12">
      <div className="mb-10 text-center">
        <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center">
          <BrandLogo size={80} />
        </div>
        <h1 className="text-3xl font-bold">Kiddotasks</h1>
        <p className="mt-2 text-ink-secondary">Missions for kids. Support for parents.</p>
        <p className="mt-2 text-sm text-ink-tertiary">
          No kid emails · No bank account · PIN login · Free plan that stays free
        </p>
      </div>

      <section className="card">
        <h2 className="mb-3 text-center font-bold">How it works</h2>
        <div className="grid gap-3 text-center sm:grid-cols-3">
          {[
            ["1", "Add your family", "Kids, avatars, PIN"],
            ["2", "Assign missions", "Daily or weekly"],
            ["3", "Celebrate", "Stars, rewards, games"],
          ].map(([n, title, sub]) => (
            <div key={n} className="rounded-xl bg-surface p-3">
              <p className="text-lg font-bold text-primary">{n}</p>
              <p className="text-sm font-semibold">{title}</p>
              <p className="text-xs text-ink-secondary">{sub}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="card">
        <h2 className="mb-3 text-center font-bold">Built for real families</h2>
        <ul className="space-y-2 text-sm text-ink-secondary">
          <li>✓ No kid email or bank account — family PIN only</li>
          <li>✓ Free plan that stays free (1 kid · 20 chores)</li>
          <li>✓ Premium ₱199/mo when you need co-parents or more kids</li>
          <li>✓ Web + iOS share the same family</li>
        </ul>
        <p className="mt-4 text-center text-xs text-ink-tertiary">
          <Link href="/how-to" className="underline">How it works</Link>
          {" · "}
          <Link href="/pricing" className="underline">Pricing</Link>
          {" · "}
          <Link href="/blog/summer-missions" className="underline">Summer guide</Link>
        </p>
      </section>

      <div className="card space-y-4">
        {!isFirebaseConfigured && (
          <p className="rounded-xl bg-warning/15 p-3 text-sm text-ink">
            Firebase isn’t configured. Copy <code>.env.example</code> →{" "}
            <code>.env.local</code> and fill in your web app keys.
          </p>
        )}

        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          {(
            [
              ["signin", "Sign in"],
              ["signup", "Create"],
              ["join", "Join"],
              ["kids", "Kids PIN"],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              onClick={() => setMode(key)}
              className={`rounded-xl px-2 py-2 text-sm font-semibold ${
                mode === key
                  ? "bg-primary text-white"
                  : "bg-surface text-ink-secondary"
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <form onSubmit={handleAuth} className="space-y-3">
          {(mode === "signup" || mode === "join") && mode === "signup" && (
            <>
              <div>
                <label className="field-label">Family name</label>
                <input
                  className="field-input"
                  value={familyName}
                  onChange={(e) => setFamilyName(e.target.value)}
                />
              </div>
              <div>
                <label className="field-label">Your name</label>
                <input
                  className="field-input"
                  value={parentName}
                  onChange={(e) => setParentName(e.target.value)}
                />
              </div>
            </>
          )}

          {mode === "join" && (
            <div>
              <label className="field-label">Family code</label>
              <input
                className="field-input uppercase"
                placeholder="KDO-XXXX"
                value={familyCode}
                onChange={(e) => setFamilyCode(e.target.value)}
              />
            </div>
          )}

          {mode === "kids" ? (
            <div>
              <label className="field-label">Family PIN</label>
              <input
                className="field-input"
                inputMode="numeric"
                placeholder="4–6 digits"
                value={pin}
                onChange={(e) =>
                  setPin(e.target.value.replace(/\D/g, "").slice(0, 6))
                }
              />
            </div>
          ) : (
            <>
              <div>
                <label className="field-label">Email</label>
                <input
                  className="field-input"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              <div>
                <label className="field-label">Password</label>
                <input
                  className="field-input"
                  type="password"
                  autoComplete={mode === "signup" ? "new-password" : "current-password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </>
          )}

          {error && <p className="text-sm text-error">{error}</p>}

          <button className="btn-primary" type="submit" disabled={busy}>
            {busy
              ? "Please wait…"
              : mode === "signin"
                ? "Sign in"
                : mode === "signup"
                  ? "Create family"
                  : mode === "join"
                    ? "Join family"
                    : "Open Kids Station"}
          </button>
        </form>

        <p className="text-center text-xs text-ink-tertiary">
          Same cloud family as the iOS app.{" "}
          <Link href="/pricing" className="text-primary underline">
            See plans
          </Link>
        </p>
      </div>
    </main>
  );
}
