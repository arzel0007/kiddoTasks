import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "How Kiddotasks works — 3 steps to calmer chore time",
  description:
    "Add your family, assign missions, celebrate progress. A short guide for parents using Kiddotasks.",
};

export default function HowToPage() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <Link href="/" className="text-sm text-primary">
        ← Home
      </Link>
      <h1 className="mt-4 text-3xl font-bold">How Kiddotasks works</h1>
      <p className="mt-2 text-ink-secondary">
        Most families are up and running in a few minutes.
      </p>
      <ol className="mt-8 list-decimal space-y-6 pl-6">
        <li>
          <p className="font-bold">Create your family</p>
          <p className="text-ink-secondary">
            Sign up with email. Add your kids with names and avatars. Set a Kids PIN for the shared iPad.
          </p>
        </li>
        <li>
          <p className="font-bold">Assign missions</p>
          <p className="text-ink-secondary">
            Daily or weekly chores with stars. Approve when you want a parent check-off.
          </p>
        </li>
        <li>
          <p className="font-bold">Celebrate progress</p>
          <p className="text-ink-secondary">
            Kids see their own space, earn stars, unlock rewards — and play together in Games.
          </p>
        </li>
      </ol>
      <Link href="/" className="btn-primary mt-10 inline-flex w-auto px-6">
        Start free
      </Link>
    </main>
  );
}
