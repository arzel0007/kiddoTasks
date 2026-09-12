import Link from "next/link";

const tiers = [
  {
    name: "Free",
    price: "$0",
    period: "forever",
    features: [
      "1 family · up to 2 kids",
      "Tasks, approvals, rewards",
      "7-day history",
      "Kids Station (PIN)",
    ],
    cta: "Start free",
    href: "/",
  },
  {
    name: "Family Plus",
    price: "$6",
    period: "/month",
    highlight: true,
    features: [
      "Unlimited kids",
      "Full history + CSV export",
      "Custom reward photos",
      "Advanced weekly charts",
      "Priority sync",
    ],
    cta: "Upgrade to Plus",
    href: "/parent/billing",
  },
  {
    name: "Family Pro",
    price: "$14",
    period: "/month",
    features: [
      "Everything in Plus",
      "Multi-household",
      "Task template packs",
      "Calendar view",
      "Unlimited co-parents",
    ],
    cta: "Talk to us",
    href: "/parent/billing",
  },
];

export default function PricingPage() {
  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <div className="mb-12 text-center">
        <Link href="/" className="text-sm text-primary">
          ← Back
        </Link>
        <h1 className="mt-4 text-4xl font-bold">Simple family pricing</h1>
        <p className="mt-2 text-ink-secondary">
          Core chores stay free. Upgrade when your family grows.
        </p>
      </div>
      <div className="grid gap-6 md:grid-cols-3">
        {tiers.map((t) => (
          <div
            key={t.name}
            className={`card flex flex-col ${
              t.highlight ? "ring-2 ring-primary" : ""
            }`}
          >
            {t.highlight && (
              <span className="mb-2 self-start rounded-full bg-primary/10 px-3 py-1 text-xs font-bold text-primary">
                Most popular
              </span>
            )}
            <h2 className="text-xl font-bold">{t.name}</h2>
            <p className="mt-2 text-3xl font-bold">
              {t.price}
              <span className="text-base font-medium text-ink-secondary">
                {t.period}
              </span>
            </p>
            <ul className="mt-4 flex-1 space-y-2 text-sm text-ink-secondary">
              {t.features.map((f) => (
                <li key={f}>• {f}</li>
              ))}
            </ul>
            <Link href={t.href} className="btn-primary mt-6">
              {t.cta}
            </Link>
          </div>
        ))}
      </div>
    </main>
  );
}
