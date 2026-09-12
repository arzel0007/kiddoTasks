"use client";

/** Category accents — Calm Adventure semantic palette. */
export const CATEGORY_COLORS: Record<string, string> = {
  household: "#3978A8",
  learning: "#6F9FBD",
  health: "#3F8B70",
  personal: "#D59A3A",
  pets: "#8B99A8",
  other: "#647487",
};

/**
 * Maps iOS SF Symbol names to web-friendly glyphs.
 * Keep in sync with KiddoIconCatalog / task defaults on iOS.
 */
export function sfSymbolToGlyph(icon: string | undefined | null): string {
  const s = (icon ?? "").toLowerCase();
  const map: [string, string][] = [
    ["bed.double", "🛏️"],
    ["bed", "🛏️"],
    ["fork.knife", "🍴"],
    ["fork", "🍴"],
    ["carrot", "🥕"],
    ["birthday.cake", "🎂"],
    ["cup.and.saucer", "☕"],
    ["takeoutbag", "🥤"],
    ["trash", "🗑️"],
    ["washer", "🧺"],
    ["tshirt", "👕"],
    ["shower", "🚿"],
    ["sofa", "🛋️"],
    ["house", "🏠"],
    ["window.awning", "🪟"],
    ["lightbulb", "💡"],
    ["book", "📚"],
    ["pencil", "✏️"],
    ["backpack", "🎒"],
    ["graduationcap", "🎓"],
    ["ruler", "📏"],
    ["doc.text", "📄"],
    ["calculator", "🧮"],
    ["mouth", "🦷"],
    ["figure.run", "🏃"],
    ["heart", "❤️"],
    ["cross.case", "🩹"],
    ["leaf", "🌿"],
    ["drop", "💧"],
    ["gamecontroller", "🎮"],
    ["music.note", "🎵"],
    ["sportscourt", "🏀"],
    ["figure.play", "⚽"],
    ["paintpalette", "🎨"],
    ["theatermasks", "🎭"],
    ["party.popper", "🎉"],
    ["pawprint", "🐾"],
    ["tortoise", "🐢"],
    ["fish", "🐟"],
    ["bird", "🐦"],
    ["cart", "🛒"],
    ["hammer", "🔨"],
    ["wrench", "🔧"],
    ["shippingbox", "📦"],
    ["bubbles", "🫧"],
    ["gift", "🎁"],
    ["tv", "📺"],
    ["film", "🎬"],
    ["headphones", "🎧"],
    ["dice", "🎲"],
    ["puzzlepiece", "🧩"],
    ["beach.umbrella", "🏖️"],
    ["airplane", "✈️"],
    ["car.fill", "🚗"],
    ["car.", "🚗"],
    ["movieclapper", "🎬"],
    ["ticket", "🎟️"],
    ["storefront", "🏪"],
    ["sparkles", "✨"],
    ["star", "⭐"],
    ["crown", "👑"],
    ["moon.stars", "🌙"],
    ["clock", "🕘"],
    ["iphone", "📱"],
    ["checkmark.circle", "✅"],
    ["checkmark", "✅"],
    ["bolt", "⚡"],
    ["paw", "🐾"],
    ["broom", "🧹"],
    ["paintbrush", "🖌️"],
    ["frying.pan", "🍳"],
    ["mug", "☕"],
    ["paperplane", "✉️"],
    ["calendar", "📅"],
    ["folder", "📁"],
    ["archivebox", "📦"],
    ["key", "🔑"],
    ["bandage", "🩹"],
    ["stethoscope", "🩺"],
    ["eye", "👁️"],
    ["camera", "📷"],
    ["basketball", "🏀"],
    ["guitars", "🎸"],
    ["highlighter", "🖍️"],
    ["globe", "🌍"],
    ["sink", "🚰"],
    ["toilet", "🚽"],
    ["oven", "♨️"],
    ["refrigerator", "🧊"],
    ["ladybug", "🐞"],
    ["hand.raised", "✋"],
  ];
  for (const [needle, glyph] of map) {
    if (s.includes(needle)) return glyph;
  }
  return "✅";
}

export function categoryColor(category: string | undefined): string {
  return CATEGORY_COLORS[(category ?? "other").toLowerCase()] ?? CATEGORY_COLORS.other;
}

type AvatarProps = {
  emoji?: string;
  colorHex?: string;
  photoURL?: string | null;
  photoData?: string | null;
  size?: number;
  name?: string;
};

/** Avatar that prefers Storage photoURL, then inline photoData, then emoji. */
export function ChildAvatar({
  emoji = "🧒",
  colorHex = "#3978A8",
  photoURL,
  photoData,
  size = 48,
  name,
}: AvatarProps) {
  // Prefer Storage download URL (direct <img> avoids CORS fetch issues).
  // Fall back to inline base64 photoData from older iOS snapshots.
  const src =
    photoURL && photoURL.length > 0
      ? photoURL
      : photoData
        ? normalizeImageData(photoData)
        : null;

  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-full ring-2 ring-surface-card"
      style={{
        width: size,
        height: size,
        background: src ? "#e5e7eb" : `${colorHex}40`,
      }}
      title={name}
    >
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt={name ?? "avatar"}
          className="h-full w-full object-cover"
          onError={(e) => {
            (e.currentTarget as HTMLImageElement).style.display = "none";
          }}
        />
      ) : (
        <div
          className="flex h-full w-full items-center justify-center"
          style={{ fontSize: size * 0.48 }}
        >
          {emoji}
        </div>
      )}
    </div>
  );
}

function normalizeImageData(data: string): string {
  if (data.startsWith("data:")) return data;
  // Firestore may store raw base64 from iOS JSON encoding
  return `data:image/jpeg;base64,${data}`;
}

export function IconTile({
  icon,
  category,
  size = 44,
  reward,
}: {
  icon?: string;
  category?: string;
  size?: number;
  reward?: boolean;
}) {
  const bg = reward ? "#D59A3A" : categoryColor(category);
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-2xl text-white"
      style={{
        width: size,
        height: size,
        background: bg,
        fontSize: size * 0.45,
      }}
    >
      {sfSymbolToGlyph(icon)}
    </div>
  );
}
