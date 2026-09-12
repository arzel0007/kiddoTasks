/** Birthday helpers — who is celebrating in the next N days. */

export type UpcomingBirthday = {
  id: string;
  name: string;
  daysUntil: number;
  emoji: string;
  colorHex: string;
  isToday: boolean;
};

function toMs(value: unknown): number {
  if (value == null) return 0;
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : 0;
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "object") {
    const o = value as Record<string, unknown>;
    if (typeof o.toMillis === "function") {
      try {
        return (o.toMillis as () => number)();
      } catch {
        /* ignore */
      }
    }
    if (typeof o.seconds === "number") return o.seconds * 1000;
  }
  return 0;
}

export function upcomingBirthdays(
  children: { id: string; name: string; avatar: { emoji: string; colorHex: string }; dateOfBirth?: string | null }[],
  windowDays = 7
): UpcomingBirthday[] {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return children
    .map((c) => {
      const dobMs = toMs(c.dateOfBirth);
      if (!dobMs) return null;
      const dob = new Date(dobMs);
      let next = new Date(today.getFullYear(), dob.getMonth(), dob.getDate());
      if (next.getTime() < today.getTime()) {
        next = new Date(today.getFullYear() + 1, dob.getMonth(), dob.getDate());
      }
      const daysUntil = Math.round((next.getTime() - today.getTime()) / 86400000);
      if (daysUntil < 0 || daysUntil > windowDays) return null;
      return {
        id: c.id,
        name: c.name,
        daysUntil,
        emoji: c.avatar.emoji,
        colorHex: c.avatar.colorHex,
        isToday: daysUntil === 0,
      };
    })
    .filter(Boolean)
    .sort((a, b) => a!.daysUntil - b!.daysUntil) as UpcomingBirthday[];
}

export function birthdayMessage(b: UpcomingBirthday): string {
  if (b.isToday) return `It's ${b.name}'s birthday today!`;
  if (b.daysUntil === 1) return `${b.name}'s birthday is tomorrow`;
  return `${b.name}'s birthday is in ${b.daysUntil} days`;
}
