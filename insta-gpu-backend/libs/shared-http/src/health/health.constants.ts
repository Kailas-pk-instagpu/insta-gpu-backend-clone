export const SERVICE_INFO = Symbol("SERVICE_INFO");

/** A dependency the service needs before it can take traffic (e.g. the database). Throws when not ready. */
export type ReadinessCheck = () => Promise<void>;

export interface ServiceInfo {
  name: string;
  version: string;
  /** Checked by GET /readyz, e.g. { database: () => pingDb() }. */
  readiness?: Record<string, ReadinessCheck>;
}

/** Metadata key behind @Public() (libs/shared-auth): the global JwtAuthGuard lets these handlers through without a token. */
export const PUBLIC_KEY = "instagpu:public";
