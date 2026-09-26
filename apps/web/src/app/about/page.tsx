import type { Metadata } from "next";
import Link from "next/link";
import {
  ABOUT_CLOSING,
  ABOUT_PARAGRAPHS,
  ABOUT_SIGNOFF,
  ABOUT_TAGLINE,
  ABOUT_TITLE,
} from "@/lib/about";
import { BrandLogo } from "@/components/brand-logo";

export const metadata: Metadata = {
  title: "About KiddoTasks — Growing capable kids",
  description:
    "Why KiddoTasks exists: helping children build skills, habits, and confidence through everyday chores—not just points.",
};

export default function AboutPage() {
  return (
    <main className="page-wash min-h-screen">
      <header className="landing-header">
        <div className="mx-auto flex w-full max-w-3xl items-center justify-between gap-3 px-5 py-3 sm:px-8">
          <Link href="/" className="flex min-w-0 items-center gap-2.5">
            <BrandLogo size={40} />
            <div className="min-w-0">
              <p
                className="truncate text-lg font-bold tracking-tight"
                style={{ fontFamily: "ui-rounded, system-ui, sans-serif" }}
              >
                KiddoTasks
              </p>
            </div>
          </Link>
          <Link href="/" className="chip-btn chip-btn--ghost">
            ← Back
          </Link>
        </div>
      </header>

      <article className="mx-auto w-full max-w-3xl px-5 pb-20 pt-10 sm:px-8">
        <p className="text-xs font-bold uppercase tracking-wider text-ink-tertiary">
          Our story
        </p>
        <h1
          className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl"
          style={{ fontFamily: "ui-rounded, system-ui, sans-serif" }}
        >
          {ABOUT_TITLE}
        </h1>
        <p className="mt-3 text-lg text-primary">{ABOUT_TAGLINE}</p>

        <div className="mt-8 space-y-5 text-base leading-relaxed text-ink-secondary">
          {ABOUT_PARAGRAPHS.map((p, i) => (
            <p
              key={i}
              className={
                p === "But the goal is bigger than earning points."
                  ? "text-lg font-semibold text-ink"
                  : undefined
              }
            >
              {p}
            </p>
          ))}
        </div>

        <div className="card mt-10 border-primary/30 bg-primary-light/40">
          <p className="text-lg font-semibold leading-relaxed text-ink">
            {ABOUT_CLOSING}
          </p>
          <p className="mt-4 text-sm font-semibold text-primary">{ABOUT_SIGNOFF}</p>
        </div>

        <div className="mt-10 flex flex-wrap gap-2">
          <Link href="/" className="btn-primary inline-flex w-auto px-6">
            Start free
          </Link>
          <Link href="/how-to" className="btn-secondary inline-flex w-auto px-6">
            How it works
          </Link>
        </div>
      </article>
    </main>
  );
}
