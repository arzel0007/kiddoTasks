"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { firebaseAuth, isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import { PageSkeleton } from "@/components/skeleton";
import { toast } from "@/components/toast";
import {
  ArzAvatar,
  arzHandle,
  arzTitleFromPath,
} from "@/components/arz-companion";
import {
  IconFamily,
  IconHistory,
  IconPlan,
  IconRewards,
  IconTasks,
  IconToday,
  IconWishlist,
} from "@/components/icons";

const tabs = [
  { href: "/parent/today", label: "Today", Icon: IconToday },
  { href: "/parent/tasks", label: "Tasks", Icon: IconTasks },
  { href: "/parent/rewards", label: "Rewards", Icon: IconRewards },
  { href: "/parent/wishlist", label: "Wishlist", Icon: IconWishlist },
  { href: "/parent/family", label: "Family", Icon: IconFamily },
  { href: "/parent/history", label: "History", Icon: IconHistory },
  { href: "/parent/billing", label: "Plan", Icon: IconPlan },
];

/** Shown when the device is in Kids Mode — parent UI must not render. */
function ParentLocked() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-page px-4">
      <div className="card w-full max-w-sm text-center">
        <p className="text-3xl" aria-hidden>
          🔒
        </p>
        <h1 className="mt-3 text-xl font-bold text-ink">Parent area locked</h1>
        <p className="mt-2 text-sm text-ink-secondary">
          This device is in Kids Mode. Ask a parent to unlock, or open Kids Station.
        </p>
        <Link href="/kids" className="btn-primary mt-4 inline-flex w-auto px-5">
          Go to Kids Station
        </Link>
      </div>
    </div>
  );
}

export default function ParentLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { family, loading, kidsMode, loadFamilyForParent, reset } = useFamilyStore();
  // Initialize to null — never call firebaseAuth() during SSR prerender.
  const [authUser, setAuthUser] = useState<User | null>(null);
  // True once Firebase has reported auth state at least once (or Firebase is off).
  const [authReady, setAuthReady] = useState(!isFirebaseConfigured);
  const pageTitle = arzTitleFromPath(pathname);

  useEffect(() => {
    if (!isFirebaseConfigured) return;
    const auth = firebaseAuth();
    if (auth.currentUser) {
      setAuthUser(auth.currentUser);
      setAuthReady(true);
      void loadFamilyForParent(auth.currentUser.uid);
    }
    let logoutTimer: ReturnType<typeof setTimeout> | undefined;
    const unsub = onAuthStateChanged(auth, (user) => {
      setAuthUser(user);
      setAuthReady(true);
      if (user) {
        if (logoutTimer) clearTimeout(logoutTimer);
        void loadFamilyForParent(user.uid);
      } else {
        // Redirect immediately — the render guard below already withholds
        // parent UI. Timer is only a safety net if replace() is interrupted.
        logoutTimer = setTimeout(() => {
          if (!firebaseAuth().currentUser) {
            reset();
            router.replace("/");
          }
        }, 600);
        reset();
        router.replace("/");
      }
    });
    return () => {
      if (logoutTimer) clearTimeout(logoutTimer);
      unsub();
    };
  }, [loadFamilyForParent, reset, router]);

  useEffect(() => {
    arzHandle("dashboardOpened");
  }, [pathname]);

  // Re-pull family data when the tab regains focus so approvals made on
  // another device (e.g. iOS) show up without a full reload.
  useEffect(() => {
    if (!isFirebaseConfigured) return;
    const refresh = () => {
      const user = firebaseAuth().currentUser;
      if (user) void loadFamilyForParent(user.uid);
    };
    window.addEventListener("focus", refresh);
    return () => window.removeEventListener("focus", refresh);
  }, [loadFamilyForParent]);

  // Redirect as soon as auth resolves signed-out (not only after the 600ms timer).
  useEffect(() => {
    if (authReady && !authUser) {
      reset();
      router.replace("/");
    }
  }, [authReady, authUser, reset, router]);

  // Synchronous guards — never render parent chrome for kids or signed-out users.
  if (kidsMode) {
    return <ParentLocked />;
  }
  if (!authReady || !authUser) {
    return <PageSkeleton />;
  }

  return (
    <div className="min-h-screen bg-page">
      <div className="mx-auto flex w-full max-w-4xl flex-col px-4 pb-10 pt-3">
        {/* Flat page header matching Today: [Arz] Title · actions. mb-5 keeps gap before nav/content. */}
        <header className="mb-5 flex min-h-[96px] items-center gap-3">
          <ArzAvatar />
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-2xl font-bold text-ink">{pageTitle}</h1>
            {family?.name ? (
              <p className="truncate text-sm text-ink-secondary">{family.name}</p>
            ) : null}
          </div>
          <Link
            href="/kids"
            className="shrink-0 rounded-xl px-3 py-2 text-xs font-semibold text-primary"
            style={{ background: "var(--color-primary-light)" }}
          >
            Kids Station
          </Link>
          <button
            type="button"
            className="shrink-0 rounded-xl border border-border px-3 py-2 text-xs font-semibold text-ink-secondary"
            onClick={async () => {
              try {
                if (isFirebaseConfigured) await signOut(firebaseAuth());
                reset();
                toast.success("Signed out.");
                router.push("/");
              } catch {
                toast.error("Couldn’t sign out — try again.");
              }
            }}
          >
            Sign out
          </button>
        </header>

        <nav className="mb-5 flex flex-wrap gap-1.5" aria-label="Primary">
          {tabs.map(({ href, label, Icon }) => {
            const active = pathname?.startsWith(href);
            return (
              <Link key={href} href={href} className={`nav-item ${active ? "is-active" : ""}`}>
                <Icon size={16} />
                {label}
              </Link>
            );
          })}
        </nav>

        <main className="flex-1">
          {loading && !family ? <PageSkeleton /> : children}
        </main>
      </div>
    </div>
  );
}
