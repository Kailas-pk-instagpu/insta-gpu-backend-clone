import { DynamicModule, Module, Type } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { loadConfig, oidcSchema } from "@instagpu/shared-config";
import { JwtAuthGuard, type AuthOptions } from "./jwt.guard";
import { AUTH_OPTIONS, PRINCIPAL_RESOLVER, type PrincipalResolver } from "./principal-resolver";

/**
 * Register once in a service's AppModule:
 *   AuthModule.forService("auth-service", { resolver: DbPrincipalResolver, imports: [...] })
 * Installs JwtAuthGuard as a GLOBAL guard (deny by default; @Public() opts out). OIDC settings come from env (OIDC_ISSUER,
 * OIDC_JWKS_URL, OIDC_AUDIENCE), validated at startup.
 */
@Module({})
export class AuthModule {
  static forService(service: string, opts: { resolver: Type<PrincipalResolver>; imports?: DynamicModule["imports"]; auth?: Partial<AuthOptions> }): DynamicModule {
    return {
      module: AuthModule,
      imports: opts.imports ?? [],
      providers: [
        {
          provide: AUTH_OPTIONS,
          useFactory: (): AuthOptions => {
            const env = loadConfig(service, oidcSchema);
            return { issuer: env.OIDC_ISSUER, audience: env.OIDC_AUDIENCE, jwksUrl: env.OIDC_JWKS_URL, ...opts.auth };
          },
        },
        { provide: PRINCIPAL_RESOLVER, useClass: opts.resolver },
        { provide: APP_GUARD, useClass: JwtAuthGuard },
      ],
      exports: [PRINCIPAL_RESOLVER],
    };
  }
}
