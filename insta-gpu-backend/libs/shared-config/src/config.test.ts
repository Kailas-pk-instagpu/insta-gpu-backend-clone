import { describe, expect, it } from "vitest";
import { baseSchema, ConfigError, dbSchema, loadConfig, oidcSchema } from "./config";

const schema = baseSchema.merge(dbSchema).merge(oidcSchema);

describe("loadConfig", () => {
  it("parses and applies defaults", () => {
    const cfg = loadConfig("auth-service", schema, { PORT: "3001", DATABASE_URL: "postgres://u:p@h:5432/d", OIDC_ISSUER: "http://kc/realms/x" });
    expect(cfg).toMatchObject({ PORT: 3001, NODE_ENV: "development", OIDC_AUDIENCE: "instagpu-api", DB_POOL_MAX: 10 });
  });

  it("fails fast with every problem named", () => {
    expect(() => loadConfig("auth-service", schema, { PORT: "x" })).toThrow(ConfigError);
    try {
      loadConfig("auth-service", schema, { PORT: "x" });
    } catch (e) {
      const msg = (e as Error).message;
      expect(msg).toContain("Invalid configuration for auth-service");
      expect(msg).toContain("PORT");
      expect(msg).toContain("DATABASE_URL");
      expect(msg).toContain("OIDC_ISSUER");
    }
  });
});
