/** Minimal structured JSON logger (one line per event) so log tools can parse fields. Ported from the reference. */
type Level = "debug" | "info" | "warn" | "error";
const order: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

export function log(level: Level, msg: string, fields: Record<string, unknown> = {}) {
  const min = order[(process.env.LOG_LEVEL as Level) ?? "info"] ?? 20;
  if (order[level] < min) return;
  process.stdout.write(JSON.stringify({ ts: new Date().toISOString(), level, msg, service: process.env.SERVICE_NAME, ...fields }) + "\n");
}
