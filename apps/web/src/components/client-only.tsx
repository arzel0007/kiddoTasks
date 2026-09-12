"use client";

/**
 * Client-only gate so Firebase never touches SSR / RSC.
 * Children render only in the browser after mount.
 */
import { useEffect, useState } from "react";

export function ClientOnly({ children }: { children: React.ReactNode }) {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (!mounted) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center text-sm text-ink-secondary">
        Loading…
      </div>
    );
  }
  return <>{children}</>;
}
