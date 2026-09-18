"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { firebaseAuth, isFirebaseConfigured } from "@/lib/firebase";
import { useFamilyStore } from "@/lib/family-store";
import { PageSkeleton } from "@/components/skeleton";
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
} from "@/components/icons";

const tabs = [
  { href: "/parent/today", label: "Today", Icon: IconToday },
  { href: "/parent/tasks", label: "Tasks", Icon: IconTasks },
  { href: "/parent/rewards", label: "Rewards", Icon: IconRewards },
  { href: "/parent/family", label: "Family", Icon: IconFamily },
  { href: "/parent/history", label: "History", Icon: IconHistory },
  { href: "/parent/billing", label: "Plan", Icon: IconPlan },
];

export default function ParentLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { family, loading, loadFamilyForParent, reset } = useFamilyStore();
  const pageTitle = arzTitleFromPath(pathname);

  useEffect(() => {
    if (!isFirebaseConfigured) return;
    const auth = firebaseAuth();
    if (auth.currentUser) {
      void loadFamilyForParent(auth.currentUser.uid);
    }
    let logoutTimer: ReturnType<typeof setTimeout> | undefined;
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        if (logoutTimer) clearTimeout(logoutTimer);
        void loadFamilyForParent(user.uid);
      } else {
        logoutTimer = setTimeout(() => {
          if (!firebaseAuth().currentUser) {
            reset();
            router.replace("/");
          }
        }, 600);
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
              if (isFirebaseConfigured) await signOut(firebaseAuth());
              reset();
              router.push("/");
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
