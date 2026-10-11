# syntax=docker/dockerfile:1
# 레포 루트를 컨텍스트로 빌드한다.
#   docker build -f apps/server/Dockerfile .

ARG NODE_VERSION=24.21.0

FROM node:${NODE_VERSION}-alpine AS base
RUN corepack enable
WORKDIR /repo

# 1) server 와 server 가 의존하는 workspace 패키지만 남긴다.
#    lockfile 도 server 에 필요한 것만 남아서, web 의존성 변경으로 이미지가 다시 빌드되지 않는다.
FROM base AS prune
COPY . .
RUN TURBO_VERSION=$(node -p "require('./package.json').devDependencies.turbo.replace(/^[\^~]/, '')") \
  && npx --yes "turbo@${TURBO_VERSION}" prune @yaguhae/server --docker

# 2) 의존성 설치 → 빌드 → 런타임에 필요한 파일만 /out 으로 모은다.
FROM base AS build
# package.json·lockfile 만 먼저 복사해서, 소스만 바뀌면 설치 레이어를 재사용한다.
COPY --from=prune /repo/out/json/ .
RUN pnpm install --frozen-lockfile
COPY --from=prune /repo/out/full/ .
RUN pnpm exec turbo run build --filter=@yaguhae/server
# 운영 의존성과 빌드 결과만 담는다. workspace 패키지(@yaguhae/shared)는 복사본으로 들어간다.
RUN pnpm --filter @yaguhae/server deploy --prod --legacy /out

# 3) 런타임
FROM node:${NODE_VERSION}-alpine AS runner
ENV NODE_ENV=production
ENV PORT=4000
WORKDIR /app

COPY --from=build /out/package.json ./
COPY --from=build /out/node_modules ./node_modules
COPY --from=build /out/dist ./dist

# node 이미지에 기본으로 있는 비루트 사용자로 실행한다.
USER node

EXPOSE 4000
CMD ["node", "dist/main.js"]
