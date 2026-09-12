"use client";

/** KiddoTasks brand mark — same AppLogo as iOS KiddoTasksLogoMark. */
export function BrandLogo({
  size = 48,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <img
      src="/brand-logo.png"
      alt="KiddoTasks"
      width={size}
      height={size}
      className={`shrink-0 object-contain ${className}`}
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.22),
        boxShadow: "0 2px 8px rgba(15,23,42,0.15)",
      }}
    />
  );
}

export function BrandWordmark({ logoSize = 40 }: { logoSize?: number }) {
  return (
    <div className="flex items-center gap-2.5">
      <BrandLogo size={logoSize} />
      <span
        className="font-bold tracking-tight text-ink"
        style={{ fontSize: logoSize * 0.5, fontFamily: "ui-rounded, system-ui, sans-serif" }}
      >
        KiddoTasks
      </span>
    </div>
  );
}
