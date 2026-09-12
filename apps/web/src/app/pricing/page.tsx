import Link from "next/link";

const tiers = [
  {
    name: "Free",
    price: "₱0",
    period: "forever",
    features: [
      "1 kid",
      "Up to 20 chores",
      "Kids Station (PIN login)",
      "Stars & rewards",
      "No credit card required",
    ],
    cta: "Start free",
    href: "/",
  },
  {
    name: "Premium",
    price: "₱199",
    period: "/month",
    highlight: true,
    features: [
      "Unlimited kids & chores",
      "Co-parent join with family code",
      "Full history",
      "Allowance modes (flat daily / per chore)",
      "Week bonus celebrations",
      "Priority support",
    ],
    cta: "Go Premium",
    href: "/parent/billing",
  },
];

export default function PricingPage() {
  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <div className="mb-12 text-center">
        <Link href="/" className="text-sm text-primary">
          ← Back
        </Link>
        <h1 className="mt-4 text-4xl font-bold">Simple family pricing</h1>
        <p className="mt-2 text-ink-secondary">
          Free plan that stays free. Upgrade when you need co-parents or more kids.
        </p>
      </div>
      <div className="grid gap-6 md:grid-cols-2">
        {tiers.map((t) => (
          <div
            key={t.name}
            className={`card flex flex-col ${t.highlight ? "ring-2 ring-primary" : ""}`}
          >
            {t.highlight && (
              <span className="mb-2 self-start rounded-full bg-primary/10 px-3 py-1 text-xs font-bold text-primary">
                Most families choose this
              </span>
            )}
            <h2 className="text-xl font-bold">{t.name}</h2>
            <p className="mt-2 text-3xl font-bold">
              {t.price}
              <span className="text-base font-medium text-ink-secondary">{t.period}</span>
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
      <p className="mt-8 text-center text-xs text-ink-tertiary">
        No kid emails · No bank account · PIN login on shared devices
      </p>
    </main>
  );
}
