/**
 * PayMongo REST client (server-only). Secret key never leaves the server.
 * API: https://docs.paymongo.com (Subscriptions, Customers, Checkout, Webhooks)
 */
import crypto from "crypto";
import { resolvePlan, type PlanDefinition } from "./plans";

const API_BASE = "https://api.paymongo.com";

function secretKey(): string {
  const key = process.env.PAYMONGO_SECRET_KEY;
  if (!key) {
    throw new Error("PAYMONGO_SECRET_KEY is not set");
  }
  return key;
}

function authHeader(): string {
  return `Basic ${Buffer.from(`${secretKey()}:`).toString("base64")}`;
}

export function isPayMongoConfigured(): boolean {
  return Boolean(process.env.PAYMONGO_SECRET_KEY);
}

type PayMongoErrorBody = {
  errors?: { code?: string; detail?: string; title?: string }[];
};

async function pmFetch<T>(
  path: string,
  init?: RequestInit & { json?: unknown }
): Promise<T> {
  const { json, ...rest } = init ?? {};
  const res = await fetch(`${API_BASE}${path}`, {
    ...rest,
    headers: {
      Authorization: authHeader(),
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(rest.headers ?? {}),
    },
    body: json !== undefined ? JSON.stringify(json) : rest.body,
    cache: "no-store",
  });
  const text = await res.text();
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = null;
  }
  if (!res.ok) {
    const err = parsed as PayMongoErrorBody;
    const detail =
      err?.errors?.map((e) => e.detail ?? e.title ?? e.code).join("; ") ||
      `PayMongo ${res.status}`;
    throw new Error(detail);
  }
  return parsed as T;
}

// MARK: - Customers

export type PayMongoCustomer = {
  id: string;
  attributes: Record<string, unknown>;
};

export async function createCustomer(input: {
  email: string;
  firstName?: string;
  lastName?: string;
}): Promise<PayMongoCustomer> {
  const body = {
    data: {
      attributes: {
        email: input.email,
        first_name: input.firstName || "Parent",
        last_name: input.lastName || "KiddoTasks",
      },
    },
  };
  const res = await pmFetch<{ data: PayMongoCustomer }>("/v1/customers", {
    method: "POST",
    json: body,
  });
  return res.data;
}

export async function retrieveCustomer(id: string): Promise<PayMongoCustomer> {
  const res = await pmFetch<{ data: PayMongoCustomer }>(`/v1/customers/${id}`);
  return res.data;
}

// MARK: - Plans

export type PayMongoPlan = {
  id: string;
  attributes: Record<string, unknown>;
};

export async function createPlan(plan: PlanDefinition): Promise<PayMongoPlan> {
  const body = {
    data: {
      attributes: {
        name: plan.name,
        amount: plan.amount,
        currency: plan.currency,
        interval: plan.interval,
        interval_count: plan.intervalCount,
      },
    },
  };
  const res = await pmFetch<{ data: PayMongoPlan }>("/v1/subscriptions/plans", {
    method: "POST",
    json: body,
  });
  return res.data;
}

// MARK: - Subscriptions

export type PayMongoSubscription = {
  id: string;
  attributes: {
    status: string;
    customer_id?: string;
    next_billing_schedule?: string | null;
    cancelled_at?: number | null;
    latest_invoice?: {
      id?: string;
      amount?: number;
      currency?: string;
      status?: string;
      payment_intent?: { id?: string; status?: string; client_key?: string };
    } | null;
    plan?: { id?: string; amount?: number; name?: string } | null;
  };
};

export async function createSubscription(input: {
  customerId: string;
  planId: string;
}): Promise<PayMongoSubscription> {
  const body = {
    data: {
      attributes: {
        customer_id: input.customerId,
        plan_id: input.planId,
      },
    },
  };
  const res = await pmFetch<{ data: PayMongoSubscription }>("/v1/subscriptions", {
    method: "POST",
    json: body,
  });
  return res.data;
}

export async function retrieveSubscription(
  id: string
): Promise<PayMongoSubscription> {
  const res = await pmFetch<{ data: PayMongoSubscription }>(
    `/v1/subscriptions/${id}`
  );
  return res.data;
}

export async function cancelSubscription(id: string): Promise<PayMongoSubscription> {
  const res = await pmFetch<{ data: PayMongoSubscription }>(
    `/v1/subscriptions/${id}`,
    { method: "DELETE" }
  );
  return res.data;
}

// MARK: - Hosted Checkout (first payment / e-wallet redirect)

export type PayMongoCheckoutSession = {
  id: string;
  attributes: {
    checkout_url?: string;
    payment_intent?: { id?: string; client_key?: string; status?: string };
  };
};

export async function createCheckoutSession(input: {
  amount: number;
  currency: string;
  description: string;
  referenceNumber: string;
  successUrl: string;
  cancelUrl: string;
  paymentMethodTypes?: string[];
}): Promise<PayMongoCheckoutSession> {
  const body = {
    data: {
      attributes: {
        line_items: [
          {
            name: input.description,
            amount: input.amount,
            currency: input.currency,
            quantity: 1,
          },
        ],
        payment_method_types: input.paymentMethodTypes ?? [
          "card",
          "gcash",
          "maya",
        ],
        success_url: input.successUrl,
        cancel_url: input.cancelUrl,
        reference_number: input.referenceNumber,
      },
    },
  };
  const res = await pmFetch<{ data: PayMongoCheckoutSession }>(
    "/v2/checkout_sessions",
    { method: "POST", json: body }
  );
  return res.data;
}

// MARK: - Webhook signature

/**
 * Verify PayMongo-Signature header against raw body.
 * Header format: `t=<unix>,livemode=<bool>,li=<hex hmac>`
 * HMAC-SHA256(`${t}.${rawBody}`, webhookSecret)
 */
export function verifyPayMongoSignature(
  rawBody: string,
  signatureHeader: string | null,
  webhookSecret: string
): boolean {
  if (!signatureHeader || !webhookSecret) return false;
  const parts = Object.fromEntries(
    signatureHeader.split(",").map((p) => {
      const [k, ...rest] = p.trim().split("=");
      return [k, rest.join("=")];
    })
  ) as Record<string, string>;
  const t = parts.t;
  const sig = parts.li || parts.signature;
  if (!t || !sig) return false;
  const expected = crypto
    .createHmac("sha256", webhookSecret)
    .update(`${t}.${rawBody}`)
    .digest("hex");
  try {
    const a = Buffer.from(expected, "utf8");
    const b = Buffer.from(sig, "utf8");
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

/** Map PayMongo status → our subscription status. */
export function mapSubscriptionStatus(pmStatus: string): string {
  switch (pmStatus) {
    case "active":
      return "active";
    case "past_due":
      return "past_due";
    case "unpaid":
      return "unpaid";
    case "cancelled":
    case "incomplete_cancelled":
      return "canceled";
    case "incomplete":
    default:
      return "incomplete";
  }
}

/** Server-side catalog lookup used by checkout. */
export function planFromId(planId: string) {
  return resolvePlan(planId);
}
