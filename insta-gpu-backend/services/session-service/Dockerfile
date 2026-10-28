# Build from the repository root:  docker build -f services/session-service/Dockerfile -t instagpu/session-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/session-service..." build \
 && pnpm --filter "@instagpu/session-service" deploy --legacy --prod /out \
 && cp -r services/session-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3003
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3003
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3003/healthz || exit 1
CMD ["node", "dist/main.js"]
