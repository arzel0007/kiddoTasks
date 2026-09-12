"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
} from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { firebaseAuth, firebaseFunctions, isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import { BrandLogo } from "@/components/brand-logo";

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

  // Already signed in? Don't show the login form — go to Parent Center.
  useEffect(() => {
    if (!isFirebaseConfigured) {
      setCheckingSession(false);
      return;
    }
    const auth = firebaseAuth();
    if (auth.currentUser) {
      void (async () => {
        try {
          await loadFamily(auth.currentUser!.uid);
          router.replace("/parent/today");
        } catch {
          setCheckingSession(false);
        }
      })();
    }
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        void (async () => {
          try {
            await loadFamily(user.uid);
            router.replace("/parent/today");
          } catch {
            setCheckingSession(false);
          }
        })();
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
    try {
      const auth = firebaseAuth();
      if (mode === "signup") {
        const cred = await createUserWithEmailAndPassword(auth, email, password);
        const bootstrap = httpsCallable(firebaseFunctions(), "bootstrapFamily");
        await bootstrap({
          familyName,
          displayName: parentName,
          email,
        });
        await loadFamily(cred.user.uid);
      } else if (mode === "signin") {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        await loadFamily(cred.user.uid);
      } else if (mode === "join") {
        // Co-parent: create/sign-in then joinFamilyWithCode
        let cred;
        try {
          cred = await createUserWithEmailAndPassword(auth, email, password);
        } catch {
          cred = await signInWithEmailAndPassword(auth, email, password);
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
      </div>

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
