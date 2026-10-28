import { Controller, Get, Inject, ServiceUnavailableException, SetMetadata } from "@nestjs/common";
import { PUBLIC_KEY } from "./health.constants";
import { SERVICE_INFO, type ServiceInfo } from "./health.constants";

/**
 * GET /healthz  liveness: the process is up (no dependency checks, must stay cheap).
 * GET /readyz   readiness: runs the service's readiness checks (database, ...); 503 when any fails.
 * Both stay outside the /api/v1 prefix so Kong, Docker and Kubernetes probes can call them.
 */
@SetMetadata(PUBLIC_KEY, true) // probes call without a token; the global JwtAuthGuard skips @Public() routes
@Controller()
export class HealthController {
  constructor(@Inject(SERVICE_INFO) private readonly info: ServiceInfo) {}

  @Get("healthz")
  health() {
    return {
      status: "ok",
      service: this.info.name,
      version: this.info.version,
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  @Get("readyz")
  async ready() {
    const checks: Record<string, string> = {};
    let ready = true;
    for (const [name, check] of Object.entries(this.info.readiness ?? {})) {
      try {
        await check();
        checks[name] = "ok";
      } catch (err) {
        ready = false;
        checks[name] = `fail: ${(err as Error).message}`;
      }
    }
    const body = { status: ready ? "ready" : "not_ready", service: this.info.name, checks };
    if (!ready) throw new ServiceUnavailableException(body);
    return body;
  }
}
