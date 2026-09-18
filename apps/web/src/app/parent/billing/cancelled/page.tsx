"use client";

import Link from "next/link";

export default function BillingCancelledPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center px-6 py-12">
      <div className="card w-full text-center">
        <p className="text-5xl">💳</p>
        <h1 className="mt-3 text-2xl font-bold">Payment wasn&apos;t completed</h1>
        <p className="mt-2 text-sm text-ink-secondary">
          Your Premium subscription hasn&apos;t been activated. No charge was made for an
          unfinished checkout.
        </p>
        <Link href="/parent/billing" className="btn-primary mt-6 inline-flex w-auto px-6">
          Try again
        </Link>
      </div>
    </main>
  );
}
