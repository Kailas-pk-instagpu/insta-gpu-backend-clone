# Build from the repository root:  docker build -f services/billing-service/Dockerfile -t instagpu/billing-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/billing-service..." build \
 && pnpm --filter "@instagpu/billing-service" deploy --legacy --prod /out \
 && cp -r services/billing-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3004
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3004
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3004/healthz || exit 1
CMD ["node", "dist/main.js"]
