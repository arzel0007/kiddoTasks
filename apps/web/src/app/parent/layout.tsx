"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
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

type RouteDirection = "forward" | "back";
type NavPillPosition = { x: number; y: number; width: number; height: number };
type RouteViewTransition = { finished: Promise<void>; skipTransition: () => void };
type TransitionDocument = Document & {
  startViewTransition?: (callback: () => void | Promise<void>) => RouteViewTransition;
};

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
  const primaryNavRef = useRef<HTMLElement>(null);
  const hoveredNavItemRef = useRef<HTMLElement | null>(null);
  const focusedNavItemRef = useRef<HTMLElement | null>(null);
  const routePathRef = useRef(pathname ?? "/parent/today");
  const routeHistoryRef = useRef<string[]>([pathname ?? "/parent/today"]);
  const routeHistoryIndexRef = useRef(0);
  const historyTraversalTargetRef = useRef<string | null>(null);
  const pendingDirectionRef = useRef<RouteDirection | null>(null);
  const routeWaiterRef = useRef<{ path: string; resolve: () => void } | null>(null);
  const activeTransitionRef = useRef<RouteViewTransition | null>(null);
  const [navPill, setNavPill] = useState<NavPillPosition | null>(null);
  // True once Firebase has reported auth state at least once (or Firebase is off).
  const [authReady, setAuthReady] = useState(!isFirebaseConfigured);
  const pageTitle = arzTitleFromPath(pathname);

  function positionNavPill(target: HTMLElement | null) {
    const nav = primaryNavRef.current;
    if (!nav) return;
    let item = target;
    if (!item || item.getClientRects().length === 0) {
      const activeLink = nav.querySelector<HTMLElement>('.parent-nav-full[aria-current="page"]');
      item = activeLink?.getClientRects().length
        ? activeLink
        : nav.querySelector<HTMLElement>(".parent-nav-more [data-nav-highlight]");
    }
    if (!item) return;
    const navRect = nav.getBoundingClientRect();
    const itemRect = item.getBoundingClientRect();
    setNavPill({
      x: itemRect.left - navRect.left + nav.scrollLeft,
      y: itemRect.top - navRect.top + nav.scrollTop,
      width: itemRect.width,
      height: itemRect.height,
    });
  }

  function resolveNavPill() {
    positionNavPill(
      focusedNavItemRef.current ??
        hoveredNavItemRef.current ??
        primaryNavRef.current?.querySelector<HTMLElement>('.parent-nav-full[aria-current="page"]') ??
        null
    );
  }

  function waitForRoute(path: string) {
    if (routePathRef.current === path) return Promise.resolve();
    return new Promise<void>((resolve) => {
      const timeout = window.setTimeout(() => {
        routeWaiterRef.current = null;
        resolve();
      }, 3000);
      routeWaiterRef.current = {
        path,
        resolve: () => {
          window.clearTimeout(timeout);
          routeWaiterRef.current = null;
          resolve();
        },
      };
    });
  }

  function transitionRoute(path: string, direction: RouteDirection, update: () => void) {
    pendingDirectionRef.current = direction;
    const root = document.documentElement;
    root.dataset.routeDirection = direction;
    const transitionDocument = document as TransitionDocument;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (!transitionDocument.startViewTransition || reducedMotion) {
      delete root.dataset.routeDirection;
      update();
      return;
    }

    try {
      activeTransitionRef.current?.skipTransition();
    } catch {
      activeTransitionRef.current = null;
    }
    try {
      const transition = transitionDocument.startViewTransition(async () => {
        update();
        await waitForRoute(path);
      });
      activeTransitionRef.current = transition;
      const clearTransition = () => {
        if (activeTransitionRef.current !== transition) return;
        activeTransitionRef.current = null;
        delete root.dataset.routeDirection;
      };
      void transition.finished.then(clearTransition, clearTransition);
    } catch {
      delete root.dataset.routeDirection;
      update();
    }
  }

  function handlePageLinkClick(event: React.MouseEvent<HTMLDivElement>) {
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      !(event.target instanceof Element)
    ) return;
    const anchor = event.target.closest<HTMLAnchorElement>("a[href]");
    if (!anchor || anchor.target === "_blank" || anchor.hasAttribute("download")) return;
    const destination = new URL(anchor.href);
    if (
      destination.origin !== window.location.origin ||
      destination.pathname === routePathRef.current ||
      !destination.pathname.startsWith("/parent/")
    ) return;
    event.preventDefault();
    const href = `${destination.pathname}${destination.search}${destination.hash}`;
    transitionRoute(destination.pathname, "forward", () => router.push(href));
  }

  useLayoutEffect(() => {
    const nextPath = pathname ?? "/";
    if (nextPath !== routePathRef.current) {
      routePathRef.current = nextPath;
      const direction = pendingDirectionRef.current ?? "forward";
      const isHistoryTraversal = historyTraversalTargetRef.current === nextPath;
      if (direction === "forward" && !isHistoryTraversal) {
        const history = routeHistoryRef.current.slice(0, routeHistoryIndexRef.current + 1);
        history.push(nextPath);
        routeHistoryRef.current = history;
        routeHistoryIndexRef.current = history.length - 1;
      } else if (!isHistoryTraversal && routeHistoryRef.current[routeHistoryIndexRef.current] !== nextPath) {
        routeHistoryRef.current = [nextPath];
        routeHistoryIndexRef.current = 0;
      }
      historyTraversalTargetRef.current = null;
      pendingDirectionRef.current = null;
      if (routeWaiterRef.current?.path === nextPath) routeWaiterRef.current.resolve();
    }
    resolveNavPill();
  }, [pathname, moreOpen]);

  useEffect(() => {
    const onPopState = () => {
      const destination = window.location.pathname;
      if (
        destination === routePathRef.current ||
        !destination.startsWith("/parent/") ||
        !routePathRef.current.startsWith("/parent/")
      ) return;
      const history = routeHistoryRef.current;
      const currentIndex = routeHistoryIndexRef.current;
      const backIndex = history.lastIndexOf(destination, currentIndex - 1);
      const forwardIndex = history.indexOf(destination, currentIndex + 1);
      const direction: RouteDirection = backIndex >= 0 ? "back" : forwardIndex >= 0 ? "forward" : "back";
      historyTraversalTargetRef.current = destination;
      if (backIndex >= 0) routeHistoryIndexRef.current = backIndex;
      else if (forwardIndex >= 0) routeHistoryIndexRef.current = forwardIndex;
      else {
        routeHistoryRef.current = [destination];
        routeHistoryIndexRef.current = 0;
      }
      transitionRoute(destination, direction, () => undefined);
    };
    const onViewportChange = () => resolveNavPill();
    const nav = primaryNavRef.current;
    window.addEventListener("popstate", onPopState);
    window.addEventListener("resize", onViewportChange);
    nav?.addEventListener("scroll", onViewportChange);
    return () => {
      window.removeEventListener("popstate", onPopState);
      window.removeEventListener("resize", onViewportChange);
      nav?.removeEventListener("scroll", onViewportChange);
    };
  }, []);

  function targetNavItem(target: EventTarget | null) {
    if (!(target instanceof Element)) return null;
    const item = target.closest<HTMLElement>("[data-nav-highlight]");
    return primaryNavRef.current?.contains(item) ? item : null;
  }

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
    <div className="min-h-screen bg-page" onClickCapture={handlePageLinkClick}>
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

        <nav
          ref={primaryNavRef}
          className="parent-primary-nav mb-5 flex gap-1.5"
          aria-label="Primary"
          onPointerOver={(event) => {
            hoveredNavItemRef.current = targetNavItem(event.target);
            resolveNavPill();
          }}
          onPointerLeave={() => {
            hoveredNavItemRef.current = null;
            resolveNavPill();
          }}
          onFocusCapture={(event) => {
            focusedNavItemRef.current = targetNavItem(event.target);
            resolveNavPill();
          }}
          onBlurCapture={(event) => {
            focusedNavItemRef.current = targetNavItem(event.relatedTarget);
            resolveNavPill();
          }}
        >
          <span
            aria-hidden="true"
            className="parent-nav-pill"
            style={{
              opacity: navPill ? 1 : 0,
              width: navPill?.width,
              height: navPill?.height,
              transform: `translate3d(${navPill?.x ?? 0}px, ${navPill?.y ?? 0}px, 0)`,
            }}
          />
          {tabs.map(({ href, label, Icon }) => {
            const active = pathname?.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                aria-current={active ? "page" : undefined}
                data-nav-highlight
                className={`nav-item parent-nav-full ${active ? "is-active" : ""}`}
              >
                <Icon size={16} />
                {label}
              </Link>
            );
          })}
          <div className="parent-nav-more" ref={moreMenuRef}>
            <button type="button" data-nav-highlight className={`nav-item ${tabs.slice(3).some(({ href }) => pathname?.startsWith(href)) ? "is-active" : ""}`} aria-label="More parent sections" aria-controls="parent-more-menu" aria-expanded={moreOpen} onClick={() => setMoreOpen((open) => !open)}>More <span aria-hidden="true">⌄</span></button>
            {moreOpen && (
              <div className="parent-nav-menu" id="parent-more-menu">
                {tabs.slice(3).map(({ href, label, Icon }) => {
                  const active = pathname?.startsWith(href);
                  return (
                    <Link
                      key={href}
                      href={href}
                      data-nav-highlight
                      aria-current={active ? "page" : undefined}
                      className={`nav-item ${active ? "is-active" : ""}`}
                      onClick={() => setMoreOpen(false)}
                    >
                      <Icon size={16} />
                      {label}
                    </Link>
                  );
                })}
              </div>
            )}
          </div>
        </nav>

        {syncState !== "connected" && <div className="mb-4 flex items-center justify-between gap-3 rounded-xl border border-border bg-surface px-3 py-2 text-sm" role="status" aria-live="polite"><span>{syncState === "connecting" ? "Connecting to family data…" : syncState === "updating" ? "Updating family data…" : syncState === "offline" ? "Offline · showing saved family data" : "Couldn’t update family data"}</span>{(syncState === "offline" || syncState === "error") && <button className="font-semibold text-primary" type="button" onClick={retrySync}>Retry</button>}</div>}

        <main key={pathname} id="main-content" tabIndex={-1} className="parent-route-content flex-1">
          {loading && !family ? <PageSkeleton /> : children}
        </main>
      </div>
    </div>
  );
}
