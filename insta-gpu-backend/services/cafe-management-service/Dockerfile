# Build from the repository root:  docker build -f services/cafe-management-service/Dockerfile -t instagpu/cafe-management-service .
FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY . .
RUN pnpm install --frozen-lockfile \
 && pnpm --filter "@instagpu/cafe-management-service..." build \
 && pnpm --filter "@instagpu/cafe-management-service" deploy --legacy --prod /out \
 && cp -r services/cafe-management-service/dist /out/dist

FROM node:22-alpine
ENV NODE_ENV=production PORT=3002
WORKDIR /app
COPY --from=build /out .
USER node
EXPOSE 3002
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:3002/healthz || exit 1
CMD ["node", "dist/main.js"]
