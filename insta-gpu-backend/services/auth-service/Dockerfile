# Build from the repository root:  docker build -f services/auth-service/Dockerfile -t instagpu/auth-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/auth-service..." build \
 && pnpm --filter "@instagpu/auth-service" deploy --legacy --prod /out \
 && cp -r services/auth-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3001
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3001
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3001/healthz || exit 1
CMD ["node", "dist/main.js"]
