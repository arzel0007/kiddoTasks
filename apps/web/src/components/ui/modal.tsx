"use client";

import { useCallback, useEffect, useId, useRef } from "react";

type ModalProps = {
  open: boolean;
  title: string;
  description?: string;
  onClose: () => void;
  children: React.ReactNode;
};

/** Accessible dialog: focus trap, Escape, backdrop click, focus restore. */
export function Modal({ open, title, description, onClose, children }: ModalProps) {
  const titleId = useId();
  const descId = useId();
  const panelRef = useRef<HTMLDivElement>(null);
  const previouslyFocused = useRef<HTMLElement | null>(null);

  const focusables = useCallback(() => {
    const root = panelRef.current;
    if (!root) return [] as HTMLElement[];
    return Array.from(
      root.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
      )
    ).filter((el) => !el.hasAttribute("disabled") && el.offsetParent !== null);
  }, []);

  useEffect(() => {
    if (!open) return;
    previouslyFocused.current = document.activeElement as HTMLElement | null;
    const t = window.setTimeout(() => {
      const items = focusables();
      (items[0] ?? panelRef.current)?.focus();
    }, 30);

    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      window.clearTimeout(t);
      document.body.style.overflow = prevOverflow;
      previouslyFocused.current?.focus?.();
    };
  }, [open, focusables]);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") {
        e.stopPropagation();
        onClose();
        return;
      }
      if (e.key !== "Tab") return;
      const items = focusables();
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement as HTMLElement | null;
      if (e.shiftKey && active === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    }
    document.addEventListener("keydown", onKey, true);
    return () => document.removeEventListener("keydown", onKey, true);
  }, [open, onClose, focusables]);

  if (!open) return null;

  return (
    <div
      className="modal-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={description ? descId : undefined}
        tabIndex={-1}
        className="modal-panel"
      >
        <div className="mb-3 flex items-start justify-between gap-3">
          <div>
            <h2 id={titleId} className="text-xl font-bold tracking-tight">
              {title}
            </h2>
            {description ? (
              <p id={descId} className="mt-1 text-sm text-ink-secondary">
                {description}
              </p>
            ) : null}
          </div>
          <button
            type="button"
            className="modal-close shrink-0"
            onClick={onClose}
            aria-label="Close dialog"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="M6 6l12 12M18 6L6 18"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>
        <div className="text-sm leading-relaxed text-ink-secondary">{children}</div>
      </div>
    </div>
  );
}
