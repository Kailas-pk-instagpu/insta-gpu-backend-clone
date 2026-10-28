# Build from the repository root:  docker build -f services/bff-service/Dockerfile -t instagpu/bff-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/bff-service..." build \
 && pnpm --filter "@instagpu/bff-service" deploy --legacy --prod /out \
 && cp -r services/bff-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3000
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3000/healthz || exit 1
CMD ["node", "dist/main.js"]
