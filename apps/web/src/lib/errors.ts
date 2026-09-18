/** Safe message extraction — never surface `[object Event]` in UI/toasts. */
export function errorMessage(err: unknown, fallback = "Something went wrong"): string {
  if (err instanceof Error && err.message) return err.message;
  if (typeof err === "string" && err.trim()) return err;
  if (err && typeof err === "object") {
    const anyErr = err as { message?: unknown; code?: unknown; type?: unknown };
    if (typeof anyErr.message === "string" && anyErr.message.trim()) {
      return anyErr.message;
    }
    // DOM/media Event — describe instead of String(event) === "[object Event]"
    if (typeof anyErr.type === "string" && anyErr.type) {
      return `${fallback} (${anyErr.type})`;
    }
    if (typeof anyErr.code === "string" && anyErr.code) {
      return `${fallback} (${anyErr.code})`;
    }
  }
  return fallback;
}
