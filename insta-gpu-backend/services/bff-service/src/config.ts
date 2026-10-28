import { baseSchema, dbSchema, loadConfig, z } from "@instagpu/shared-config";

/** bff-service configuration, validated once at startup (fail fast). Ported from the reference console lib/config.ts. */
const schema = baseSchema.merge(dbSchema).extend({
  /** The issuer in every token = Keycloak's address as the BROWSER sees it (login page redirects go there). */
  OIDC_ISSUER: z.string().url(),
  /** Where this service reaches Keycloak itself (Docker: http://keycloak:8081/realms/instagpu). Defaults to the issuer. */
  OIDC_INTERNAL_URL: z.string().url().optional(),
  OIDC_CLIENT_ID: z.string().min(1).default("instagpu-bff"),
  OIDC_CLIENT_SECRET: z.string().min(8),
  /** Must be registered on the Keycloak client; the browser-visible callback (through the frontend's /bff proxy). */
  OIDC_REDIRECT_URI: z.string().url(),
  /** The React app; where the browser goes after login and logout. */
  FRONTEND_URL: z.string().url(),
  /** Kong proxy; /bff/api/v1/* is forwarded to KONG_URL/api/v1/*. */
  KONG_URL: z.string().url(),
  /** base64 of 32 random bytes; encrypts tokens at rest and the login cookie. DEV value in .env.example; real ones from OpenBao. */
  SESSION_ENCRYPTION_KEY: z.string().refine((v) => Buffer.from(v, "base64").length === 32, "must be base64 of exactly 32 bytes"),
  SESSION_IDLE_MINUTES: z.coerce.number().int().min(5).max(24 * 60).default(30),
  SESSION_MAX_HOURS: z.coerce.number().int().min(1).max(24 * 7).default(10),
  /** Secure cookies. Browsers accept Secure cookies on http://localhost, so this stays on in dev too. */
  COOKIE_SECURE: z.enum(["true", "false"]).default("true").transform((v) => v === "true"),
  PROXY_TIMEOUT_MS: z.coerce.number().int().min(1000).max(120_000).default(15_000),
});

export type BffConfig = z.infer<typeof schema>;

let cached: BffConfig | undefined;
export function cfg(): BffConfig {
  cached ??= loadConfig("bff-service", schema);
  return cached;
}

/** __Host- needs https; on plain http://localhost the dev names are used (as in the reference). */
const https = () => cfg().FRONTEND_URL.startsWith("https://");
export const sessionCookieName = () => (https() ? "__Host-igpu_sid" : "igpu_sid");
export const csrfCookieName = () => (https() ? "__Host-igpu_csrf" : "igpu_csrf");
export const loginCookiePrefix = () => (https() ? "__Host-igpu_login_" : "igpu_login_");
