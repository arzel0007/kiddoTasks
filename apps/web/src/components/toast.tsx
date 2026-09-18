"use client";

import { create } from "zustand";

export type ToastStyle = "success" | "error" | "info";

export type ToastItem = {
  id: string;
  style: ToastStyle;
  message: string;
};

type ToastState = {
  toasts: ToastItem[];
  push: (style: ToastStyle, message: string) => void;
  dismiss: (id: string) => void;
};

const MAX_VISIBLE = 3;
const TOAST_MS = 3200;

export const useToastStore = create<ToastState>((set, get) => ({
  toasts: [],
  push: (style, message) => {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    set((s) => ({
      toasts: [...s.toasts, { id, style, message }].slice(-MAX_VISIBLE),
    }));
    window.setTimeout(() => get().dismiss(id), TOAST_MS);
  },
  dismiss: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}));

/** Imperative toast API — safe to call from event handlers. */
export const toast = {
  success: (message: string) => useToastStore.getState().push("success", message),
  error: (message: string) => useToastStore.getState().push("error", message),
  info: (message: string) => useToastStore.getState().push("info", message),
};

const ICONS: Record<ToastStyle, string> = {
  success: "✓",
  error: "!",
  info: "i",
};

/** Global toast host — mount once in the root layout. */
export function Toaster() {
  const toasts = useToastStore((s) => s.toasts);
  const dismiss = useToastStore((s) => s.dismiss);

  return (
    <div
      className="pointer-events-none fixed inset-x-0 bottom-0 z-[100] flex flex-col items-center gap-2 px-4 pb-5 sm:pb-6"
      role="region"
      aria-label="Notifications"
      aria-live="polite"
    >
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`toast toast--${t.style} pointer-events-auto`}
          role={t.style === "error" ? "alert" : "status"}
        >
          <span className="toast__icon" aria-hidden>
            {ICONS[t.style]}
          </span>
          <p className="toast__message">{t.message}</p>
          <button
            type="button"
            className="toast__close"
            aria-label="Dismiss"
            onClick={() => dismiss(t.id)}
          >
            ×
          </button>
        </div>
      ))}
    </div>
  );
}
