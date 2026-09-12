/** Simple consistent SVG icons for parent navigation (no emoji). */
type IconProps = {
  className?: string;
  size?: number;
};

const base = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.75,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

export function IconToday({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <circle cx="12" cy="12" r="9" {...base} />
      <path d="M8.5 12.5l2.5 2.5 4.5-5" {...base} />
    </svg>
  );
}

export function IconTasks({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <path d="M8 6h11M8 12h11M8 18h11" {...base} />
      <path d="M4 6h.01M4 12h.01M4 18h.01" {...base} />
    </svg>
  );
}

export function IconRewards({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <rect x="4" y="9" width="16" height="11" rx="2" {...base} />
      <path d="M4 13h16M12 9v11" {...base} />
      <path d="M12 9c-2 0-3.5-1-3.5-2.5S10 4.5 12 6.5c2-2 3.5-1 3.5.5S14 9 12 9z" {...base} />
    </svg>
  );
}

export function IconFamily({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <circle cx="9" cy="8" r="2.5" {...base} />
      <circle cx="16" cy="9.5" r="2" {...base} />
      <path d="M4 18c0-2.5 2.2-4.5 5-4.5s5 2 5 4.5" {...base} />
      <path d="M14 18c0-1.8 1.3-3.2 3-3.2s3 1.4 3 3.2" {...base} />
    </svg>
  );
}

export function IconHistory({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <circle cx="12" cy="12" r="9" {...base} />
      <path d="M12 7v5l3 2" {...base} />
    </svg>
  );
}

export function IconPlan({ className, size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <path d="M12 3.5l2.2 4.5 5 .7-3.6 3.5.9 5L12 15.2 7.5 17.2l.9-5L4.8 8.7l5-.7L12 3.5z" {...base} />
    </svg>
  );
}

export function IconCheck({ className, size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <path d="M5 12.5l4.5 4.5L19 7.5" {...base} />
    </svg>
  );
}

export function IconGift({ className, size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <rect x="4" y="10" width="16" height="10" rx="1.5" {...base} />
      <path d="M4 14h16M12 10v10" {...base} />
    </svg>
  );
}

export function IconList({ className, size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <path d="M9 7h11M9 12h11M9 17h11" {...base} />
      <path d="M5 7h.01M5 12h.01M5 17h.01" {...base} />
    </svg>
  );
}

export function IconUsers({ className, size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden>
      <circle cx="9" cy="8" r="2.5" {...base} />
      <circle cx="16" cy="9.5" r="2" {...base} />
      <path d="M4 18c0-2.5 2.2-4.5 5-4.5s5 2 5 4.5" {...base} />
      <path d="M14 18c0-1.8 1.3-3.2 3-3.2s3 1.4 3 3.2" {...base} />
    </svg>
  );
}
