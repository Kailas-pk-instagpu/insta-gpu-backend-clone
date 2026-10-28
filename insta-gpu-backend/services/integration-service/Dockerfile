# Build from the repository root:  docker build -f services/integration-service/Dockerfile -t instagpu/integration-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/integration-service..." build \
 && pnpm --filter "@instagpu/integration-service" deploy --legacy --prod /out \
 && cp -r services/integration-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3005
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3005
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3005/healthz || exit 1
CMD ["node", "dist/main.js"]
