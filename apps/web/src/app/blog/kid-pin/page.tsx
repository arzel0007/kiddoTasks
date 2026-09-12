import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Why no kid email — Kiddotasks guide",
  description:
    "Kids use a family PIN on a shared device. No email, no bank account, no ads.",
};

export default function BlogKidPin() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <Link href="/" className="text-sm text-primary">
        ← Home
      </Link>
      <p className="mt-6 text-xs font-bold uppercase tracking-wider text-ink-tertiary">
        Guide
      </p>
      <h1 className="mt-2 text-3xl font-bold">Kids log in with a PIN — not an email</h1>
      <p className="mt-4 text-ink-secondary">
        Parents own the account. Children pick their face and enter the family PIN on a shared iPad
        or browser. No inbox, no password reset, no bank linking.
      </p>
      <ul className="mt-6 list-disc space-y-2 pl-6 text-ink-secondary">
        <li>Family PIN lives in Family settings.</li>
        <li>Works offline on the device for recent missions (iOS).</li>
        <li>Co-parent join is Premium so households stay small and intentional.</li>
      </ul>
      <Link href="/" className="btn-primary mt-8 inline-flex w-auto px-6">
        Start free
      </Link>
    </main>
  );
}
