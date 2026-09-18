"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

/** Expression states for Arz. */
export type ArzExpression =
  | "idle"
  | "happy"
  | "excited"
  | "laughing"
  | "wink"
  | "surprised"
  | "thinking"
  | "determined"
  | "encouraging"
  | "sad"
  | "sleepy";

export type ArzEvent =
  | "taskCompleted"
  | "multipleTasksCompleted"
  | "achievementUnlocked"
  | "aiProcessing"
  | "taskOverdue"
  | "error"
  | "userTap"
  | "dashboardOpened"
  | "kidsStationOpened";

const ASSET: Record<ArzExpression, string> = {
  idle: "/arz/head_happy.png",
  happy: "/arz/head_happy.png",
  excited: "/arz/head_laughing.png",
  laughing: "/arz/head_laughing.png",
  wink: "/arz/head_wink.png",
  surprised: "/arz/head_surprised.png",
  thinking: "/arz/head_thinking.png",
  determined: "/arz/head_determined.png",
  encouraging: "/arz/head_encouraging.png",
  sad: "/arz/head_sad.png",
  sleepy: "/arz/head_sleepy.png",
};

const BLINK_ASSET = "/arz/head_sleepy.png";

const HOLD_MS: Record<ArzExpression, number> = {
  idle: Number.POSITIVE_INFINITY,
  thinking: 6000,
  sleepy: 8000,
  excited: 2200,
  laughing: 2200,
  surprised: 1600,
  wink: 1400,
  happy: 1800,
  encouraging: 1800,
  determined: 1800,
  sad: 2400,
};

const PRIORITY: Record<ArzExpression, number> = {
  idle: 0,
  happy: 1,
  wink: 1,
  encouraging: 2,
  determined: 2,
  sleepy: 2,
  sad: 3,
  surprised: 3,
  laughing: 4,
  thinking: 4,
  excited: 5,
};

const EVENT_MAP: Record<ArzEvent, ArzExpression> = {
  taskCompleted: "happy",
  multipleTasksCompleted: "excited",
  achievementUnlocked: "excited",
  aiProcessing: "thinking",
  taskOverdue: "encouraging",
  error: "sad",
  userTap: "wink",
  dashboardOpened: "happy",
  kidsStationOpened: "excited",
};

const COOLDOWN_MS = 450;

export function arzPlay(expression: ArzExpression) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent("arz:play", { detail: expression }));
}

export function arzHandle(event: ArzEvent) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent("arz:event", { detail: event }));
}

function useArzState() {
  const [expression, setExpression] = useState<ArzExpression>("idle");
  const [blinking, setBlinking] = useState(false);
  const [reduceMotion, setReduceMotion] = useState(false);

  const expressionRef = useRef(expression);
  expressionRef.current = expression;
  const priorityRef = useRef(0);
  const lastPlayRef = useRef(0);
  const returnTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const blinkTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReduceMotion(mq.matches);
    const onChange = () => setReduceMotion(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  const playExpression = useCallback((next: ArzExpression, force = false) => {
    const now = Date.now();
    const inCooldown = now - lastPlayRef.current < COOLDOWN_MS;
    const current = expressionRef.current;
    if (!force) {
      if (inCooldown && PRIORITY[next] < priorityRef.current) return;
      if (inCooldown && PRIORITY[next] <= priorityRef.current && next !== current)
        return;
    }
    lastPlayRef.current = now;
    priorityRef.current = PRIORITY[next];
    setBlinking(false);
    setExpression(next);
    expressionRef.current = next;
    if (returnTimer.current) clearTimeout(returnTimer.current);
    const hold = HOLD_MS[next];
    if (Number.isFinite(hold)) {
      returnTimer.current = setTimeout(() => {
        priorityRef.current = 0;
        setExpression("idle");
        expressionRef.current = "idle";
      }, hold);
    }
  }, []);

  useEffect(() => {
    const onPlay = (e: Event) => {
      const detail = (e as CustomEvent<ArzExpression>).detail;
      if (detail in ASSET) playExpression(detail);
    };
    const onEvent = (e: Event) => {
      const detail = (e as CustomEvent<ArzEvent>).detail;
      if (detail === "userTap") {
        playExpression(expressionRef.current === "wink" ? "happy" : "wink");
        return;
      }
      playExpression(EVENT_MAP[detail] ?? "happy");
    };
    window.addEventListener("arz:play", onPlay);
    window.addEventListener("arz:event", onEvent);
    return () => {
      window.removeEventListener("arz:play", onPlay);
      window.removeEventListener("arz:event", onEvent);
    };
  }, [playExpression]);

  useEffect(() => {
    if (reduceMotion) return;
    if (expression !== "idle" && expression !== "happy") return;
    const schedule = () => {
      const delay = 2800 + Math.random() * 3000;
      blinkTimer.current = setTimeout(() => {
        setBlinking(true);
        blinkTimer.current = setTimeout(() => {
          setBlinking(false);
          schedule();
        }, 90);
      }, delay);
    };
    schedule();
    return () => {
      if (blinkTimer.current) clearTimeout(blinkTimer.current);
    };
  }, [expression, reduceMotion]);

  useEffect(() => {
    playExpression("happy", true);
  }, [playExpression]);

  return { expression, blinking, reduceMotion };
}

/** Shared display size — matches iOS `ArzAvatarMetrics.displaySize`. */
export const ARZ_AVATAR_SIZE = 80;
/** How long the tap phrase stays visible (ms). */
export const ARZ_PHRASE_MS = 2500;

/** Temporary web-only avatar: looping emotion-cycle MP4 (1280×720 H.264). */
const ARZ_VIDEO_SRC = "/arz/emotions-loop.mp4";
const ARZ_STILL_FALLBACK = "/arz/head_happy.png";

const ARZ_PHRASES = [
  {
    title: "Hi! I'm Arz 👋",
    body: "I'm here to help you and the kids stay on track!",
  },
  {
    title: "Hey there! 👋",
    body: "I'm Arz — your KiddoTasks buddy.",
  },
  {
    title: "What's up? ⭐",
    body: "Missions, stars, and high-fives. Let's go!",
  },
  {
    title: "Hi friend! 😊",
    body: "Tap me anytime you want a little cheer.",
  },
  {
    title: "Arz here! ✨",
    body: "Ready to help your family stay on track.",
  },
] as const;

let arzPhraseIndex = 0;
function nextArzPhrase() {
  const line = ARZ_PHRASES[arzPhraseIndex % ARZ_PHRASES.length];
  arzPhraseIndex += 1;
  return line;
}

function useAvatarSize() {
  return ARZ_AVATAR_SIZE;
}

/**
 * Compact Arz avatar for the page header row (replaces brand logo).
 * Web-only temporary swap: muted looping MP4 of the boy avatar cycling emotions.
 * Tap still opens the phrase bubble. Reduced-motion / load failure → PNG stills.
 */
export function ArzAvatar({
  size,
  kidName,
}: {
  size?: number;
  /** When set (Kids Station), tap greets the child by name. */
  kidName?: string;
}) {
  const { expression, blinking, reduceMotion } = useArzState();
  const [showPhrase, setShowPhrase] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [videoFailed, setVideoFailed] = useState(false);
  const [phrase, setPhrase] = useState<{ title: string; body: string }>(ARZ_PHRASES[0]);
  const dismissTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const responsive = useAvatarSize();
  const px = size ?? responsive;

  const useVideo = !reduceMotion && !videoFailed;
  const stillSrc = blinking ? BLINK_ASSET : ASSET[expression];
  const idleMotion =
    !reduceMotion && !useVideo && (expression === "idle" || expression === "happy");

  useEffect(() => {
    return () => {
      if (dismissTimer.current) clearTimeout(dismissTimer.current);
    };
  }, []);

  // Keep the loop playing when the element remounts after route changes.
  useEffect(() => {
    if (!useVideo) return;
    const el = videoRef.current;
    if (!el) return;
    void el.play().catch(() => setVideoFailed(true));
  }, [useVideo]);

  const showPhraseNow = () => {
    if (kidName) {
      setPhrase({
        title: `Hi ${kidName}! 👋`,
        body: "Ready to log your chores for today?",
      });
    } else {
      setPhrase(nextArzPhrase());
    }
    setShowPhrase(true);
    if (dismissTimer.current) clearTimeout(dismissTimer.current);
    dismissTimer.current = setTimeout(() => setShowPhrase(false), ARZ_PHRASE_MS);
  };

  return (
    <div className="relative shrink-0" style={{ width: px, height: px }}>
      <button
        type="button"
        aria-label="Arz, KiddoTasks assistant"
        aria-expanded={showPhrase}
        className={[
          "block rounded-full transition-transform duration-200",
          pressed ? "scale-95" : "scale-100",
          "hover:scale-105 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
          idleMotion ? "arz-breathe" : "",
        ].join(" ")}
        style={{ width: px, height: px }}
        onClick={() => {
          setPressed(true);
          showPhraseNow();
          window.setTimeout(() => setPressed(false), 180);
        }}
      >
        {useVideo ? (
          <video
            ref={videoRef}
            src={ARZ_VIDEO_SRC}
            width={px}
            height={px}
            muted
            loop
            playsInline
            autoPlay
            preload="auto"
            disablePictureInPicture
            aria-hidden
            className="h-full w-full rounded-full bg-white object-cover"
            style={{ objectPosition: "50% 30%" }}
            onError={() => setVideoFailed(true)}
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={videoFailed ? ARZ_STILL_FALLBACK : stillSrc}
            alt=""
            draggable={false}
            decoding="async"
            width={px * 3}
            height={px * 3}
            className="h-full w-full rounded-full object-contain [image-rendering:auto]"
          />
        )}
      </button>

      {showPhrase && (
        <div
          role="status"
          aria-live="polite"
          className="pointer-events-none absolute left-0 top-[calc(100%+8px)] z-[46] w-64 rounded-2xl border border-border bg-white p-3 shadow-card"
        >
          <div className="mb-1 h-2 w-2 -mt-5 ml-2 rotate-45 border-b border-l border-border bg-white" />
          <p className="text-sm font-bold text-ink">{phrase.title}</p>
          <p className="mt-1 text-xs text-ink-secondary">{phrase.body}</p>
        </div>
      )}
    </div>
  );
}

/** Map parent route → page title for the header. */
export function arzTitleFromPath(pathname: string | null): string {
  const path = pathname ?? "";
  if (path.startsWith("/parent/tasks")) return "Tasks";
  if (path.startsWith("/parent/rewards")) return "Rewards";
  if (path.startsWith("/parent/family")) return "Family";
  if (path.startsWith("/parent/history")) return "History";
  if (path.startsWith("/parent/billing")) return "Plan";
  if (path.startsWith("/parent/today")) return "Today";
  if (path.startsWith("/parent")) return "Today";
  return "KiddoTasks";
}
