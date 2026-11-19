"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";

type Direction = "forward" | "back";

/** Runs a 450ms page-content entrance after a client-side parent navigation. */
export function ParentRouteTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const previousPathRef = useRef(pathname);
  const clearTimerRef = useRef<number | null>(null);
  const [direction, setDirection] = useState<Direction | null>(null);

  useLayoutEffect(() => {
    if (previousPathRef.current === pathname) return;
    previousPathRef.current = pathname;

    const root = document.documentElement;
    const nextDirection = root.dataset.routeDirection === "back" ? "back" : "forward";
    setDirection(nextDirection);
    if (clearTimerRef.current !== null) window.clearTimeout(clearTimerRef.current);
    clearTimerRef.current = window.setTimeout(() => {
      delete root.dataset.routeDirection;
      setDirection(null);
      clearTimerRef.current = null;
    }, 450);
  }, [pathname]);

  return (
    <div
      key={pathname}
      className={direction ? `parent-route-enter parent-route-enter--${direction}` : undefined}
    >
      {children}
    </div>
  );
}
