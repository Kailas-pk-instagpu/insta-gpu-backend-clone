/**
 * Where to send the browser after sign-in (ported from the reference console lib/safe-redirect.ts). Only a path on the frontend is
 * allowed: "/branches?x=1" yes; "//evil.com", "/\evil.com", "https://evil.com", "javascript:…" no (URL parsers treat "\" like "/",
 * so a plain startsWith("/") check is not enough).
 */
export function safeReturnTo(value: string | null | undefined, frontendUrl: string, fallback = "/dashboard"): string {
  if (!value || !value.startsWith("/") || value.includes("\\")) return fallback;
  try {
    const base = new URL(frontendUrl);
    const u = new URL(value, base);
    if (u.origin !== base.origin) return fallback;
    return `${u.pathname}${u.search}${u.hash}` || fallback;
  } catch {
    return fallback;
  }
}
