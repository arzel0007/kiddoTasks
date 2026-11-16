import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Summer Chore Ideas for Kids",
  description:
    "Use these simple summer chore ideas to build a light daily rhythm for kids, from watering plants to tidying up and earning chosen rewards.",
  alternates: { canonical: "/blog/summer-missions" },
};

export default function BlogSummerChores() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <Link href="/" className="text-sm text-primary">
        ← Home
      </Link>
      <p className="mt-6 text-xs font-bold uppercase tracking-wider text-ink-tertiary">
        Guide
      </p>
      <h1 className="mt-2 text-3xl font-bold">Summer missions that don’t feel like homework</h1>
      <p className="mt-4 text-ink-secondary">
        Keep a light daily rhythm: one morning mission, one outdoor job, and a reward the kids chose.
        Short lists beat long checklists.
      </p>
      <ul className="mt-6 list-disc space-y-2 pl-6 text-ink-secondary">
        <li>Outdoor: water plants, wipe table after lunch, tidy shoes.</li>
        <li>Swap 20 minutes of screens for a quick mission when energy is high.</li>
        <li>Use week bonus (e.g. “movie night”) when all seven days have progress.</li>
      </ul>
      <Link href="/" className="btn-primary mt-8 inline-flex w-auto px-6">
        Try Kiddotasks free
      </Link>
    </main>
  );
}
