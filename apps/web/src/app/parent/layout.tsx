"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { onAuthStateChanged, signOut, type User } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";
import { firebaseAuth, firestore, isFirebaseConfigured } from "@/lib/firebase";
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
  const { family, loading, kidsMode, syncState, setSyncState, loadFamilyForParent, reset } = useFamilyStore();
  // Initialize to null — never call firebaseAuth() during SSR prerender.
  const [authUser, setAuthUser] = useState<User | null>(null);
  const [moreOpen, setMoreOpen] = useState(false);
  const [syncRetryKey, setSyncRetryKey] = useState(0);
  const moreMenuRef = useRef<HTMLDivElement>(null);
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
    setMoreOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!moreOpen) return;
    function closeFromOutside(event: PointerEvent) {
      if (event.target instanceof Node && !moreMenuRef.current?.contains(event.target)) setMoreOpen(false);
    }
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === "Escape") setMoreOpen(false);
    }
    document.addEventListener("pointerdown", closeFromOutside);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeFromOutside);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [moreOpen]);

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

  // All server-authoritative actions bump this document. This keeps every web
  // page in sync without depending on a focus event or manual reload.
  useEffect(() => {
    if (!isFirebaseConfigured || !authUser || !family?.id || kidsMode) return;
    return onSnapshot(doc(firestore(), "families", family.id), () => {
      setSyncState("updating");
      void loadFamilyForParent(authUser.uid);
    }, () => setSyncState("error"));
  }, [authUser, family?.id, kidsMode, loadFamilyForParent, setSyncState, syncRetryKey]);

  useEffect(() => {
    const updateConnectivity = () => setSyncState(navigator.onLine ? "connected" : "offline");
    window.addEventListener("online", updateConnectivity);
    window.addEventListener("offline", updateConnectivity);
    return () => { window.removeEventListener("online", updateConnectivity); window.removeEventListener("offline", updateConnectivity); };
  }, [setSyncState]);

  function retrySync() {
    if (authUser) void loadFamilyForParent(authUser.uid);
    setSyncState("connecting");
    setSyncRetryKey((key) => key + 1);
  }

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
        <header className="parent-header mb-5 flex min-h-[96px] items-center gap-3">
          <ArzAvatar />
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-2xl font-bold text-ink">{pageTitle}</h1>
            {family?.name ? (
              <p className="truncate text-sm text-ink-secondary">{family.name}</p>
            ) : null}
          </div>
          <div className="parent-header__actions">
            <Link
              href="/kids"
              className="shrink-0 rounded-xl px-3 py-2 text-xs font-semibold text-primary"
              style={{ background: "var(--color-primary-light)" }}
            >
              <span className="hidden sm:inline">Kids Station</span>
              <span className="sm:hidden">Kids</span>
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
          </div>
        </header>

        <nav className="parent-primary-nav mb-5 flex gap-1.5" aria-label="Primary">
          {tabs.map(({ href, label, Icon }) => {
            const active = pathname?.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                aria-current={active ? "page" : undefined}
                className={`nav-item parent-nav-full ${active ? "is-active" : ""}`}
              >
                <Icon size={16} />
                {label}
              </Link>
            );
          })}
          <div className="parent-nav-more" ref={moreMenuRef}>
            <button type="button" className={`nav-item ${tabs.slice(3).some(({ href }) => pathname?.startsWith(href)) ? "is-active" : ""}`} aria-label="More parent sections" aria-controls="parent-more-menu" aria-expanded={moreOpen} onClick={() => setMoreOpen((open) => !open)}>More <span aria-hidden="true">⌄</span></button>
            {moreOpen && <div className="parent-nav-menu" id="parent-more-menu">{tabs.slice(3).map(({ href, label, Icon }) => { const active = pathname?.startsWith(href); return <Link key={href} href={href} aria-current={active ? "page" : undefined} className={`nav-item ${active ? "is-active" : ""}`} onClick={() => setMoreOpen(false)}><Icon size={16}/>{label}</Link>; })}</div>}
          </div>
        </nav>

        {syncState !== "connected" && <div className="mb-4 flex items-center justify-between gap-3 rounded-xl border border-border bg-surface px-3 py-2 text-sm" role="status" aria-live="polite"><span>{syncState === "connecting" ? "Connecting to family data…" : syncState === "updating" ? "Updating family data…" : syncState === "offline" ? "Offline · showing saved family data" : "Couldn’t update family data"}</span>{(syncState === "offline" || syncState === "error") && <button className="font-semibold text-primary" type="button" onClick={retrySync}>Retry</button>}</div>}

        <main id="main-content" tabIndex={-1} className="flex-1">
          {loading && !family ? <PageSkeleton /> : children}
        </main>
      </div>
    </div>
  );
}
