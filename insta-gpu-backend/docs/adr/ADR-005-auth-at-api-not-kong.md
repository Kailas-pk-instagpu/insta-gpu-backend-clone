# ADR-005 Tokens validated by platform-api; Kong does transport policy only
Status: Accepted · Date: 2026-10-07

Kong 3.10 OSS has no OIDC/JWT-with-JWKS-rotation plugin suitable for this design, and Enterprise is out of budget.
Kong therefore does routing, size limits, rate limits, correlation id, security headers and metrics.
platform-api validates every bearer token (JWKS signature, iss, aud=instagpu-api, exp/nbf) and then authorizes
(role + tenant membership + branch scope). The Console BFF is the only client in V1; Kong rate-limits per BFF
session using the `x-bff-session` header because all console traffic arrives from BFF pod IPs.
