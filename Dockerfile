# Downstream Docker wrapper for m3u4me.
# Clones upstream at build time so this repo stays small and tracks latest.
ARG UPSTREAM_REPO=https://github.com/andrei-savin/m3u4me.git
ARG UPSTREAM_REF=main
ARG UPSTREAM_SHA=""

FROM node:22-alpine AS builder
ARG UPSTREAM_REPO
ARG UPSTREAM_REF
ARG UPSTREAM_SHA
RUN apk add --no-cache git
WORKDIR /app
# NOTE: UPSTREAM_SHA is referenced here on purpose. Changing it busts the
# BuildKit layer cache, so a scheduled rebuild actually fetches new code
# instead of reusing a stale `git clone` layer. A full clone + checkout
# pins the exact upstream commit (avoids races where main moves between
# ls-remote and clone, and works for tags as well as branches).
RUN rm -rf /tmp/upstream \
  && git clone "${UPSTREAM_REPO}" /tmp/upstream \
  && (if [ -n "${UPSTREAM_SHA}" ]; then git -C /tmp/upstream checkout "${UPSTREAM_SHA}"; else git -C /tmp/upstream checkout "${UPSTREAM_REF}"; fi) \
  && cp -a /tmp/upstream/. /app/ \
  && BUILT_SHA=$(git -C /app rev-parse HEAD) \
  && rm -rf /tmp/upstream /app/.git \
  && echo "Built from ${UPSTREAM_REPO} ref=${UPSTREAM_REF} sha=${BUILT_SHA}" > UPSTREAM_VERSION \
  && cat UPSTREAM_VERSION
RUN npm ci && npm run build

FROM node:22-alpine AS runner
ARG UPSTREAM_REPO
ARG UPSTREAM_REF
ARG UPSTREAM_SHA=""
LABEL upstream.repo="${UPSTREAM_REPO}" upstream.ref="${UPSTREAM_REF}" upstream.sha="${UPSTREAM_SHA}"
WORKDIR /app
# NOTE: install ALL deps (not --omit=dev). server.ts statically imports
# `vite` (a devDependency), so a prod-only install crashes on boot even
# though vite is only used in dev mode.
COPY --from=builder /app/package.json /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.ts ./
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/UPSTREAM_VERSION ./

RUN mkdir -p /app/data && chown -R node:node /app
USER node

ENV NODE_ENV=production
ENV PORT=8080
VOLUME ["/app/data"]
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/auth/status || exit 1
CMD ["node", "server.ts"]
