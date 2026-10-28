import { z } from "zod";

/**
 * All configuration comes from environment variables (dev: .env / compose; real environments: OpenBao). Ported from
 * InstaGPU-GC-Core apps/platform/src/shared/config.ts: one zod schema per process, validated once at startup.
 * A missing or malformed value stops the service with one clear message listing every problem.
 */
export const baseSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "staging", "production"]).default("development"),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
  PORT: z.coerce.number().int().min(1).max(65535),
});

export const dbSchema = z.object({
  DATABASE_URL: z.string().url(),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),
});

/** Every service that validates user tokens (ADR-005: each service checks the token itself). */
export const oidcSchema = z.object({
  OIDC_ISSUER: z.string().url(),                    // http://localhost:8081/realms/instagpu (the iss in every token)
  OIDC_JWKS_URL: z.string().url().optional(),       // defaults to <issuer>/protocol/openid-connect/certs
  OIDC_AUDIENCE: z.string().default("instagpu-api"),
});

export class ConfigError extends Error {}

/** Parse and validate env for one service; throws ConfigError naming every missing / invalid variable. */
export function loadConfig<S extends z.ZodTypeAny>(service: string, schema: S, env: NodeJS.ProcessEnv = process.env): z.infer<S> {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join(".") || "(root)"}: ${i.message}`).join("; ");
    throw new ConfigError(`Invalid configuration for ${service}: ${issues}`);
  }
  return parsed.data;
}
