# syntax=docker/dockerfile:1
# ── Supabase Edge Functions + Backend Consultation WS ────────────────────────
#
# This image hosts the Node.js WebSocket consultation server used in production.
# The Flutter app connects to this server for real-time consultation sessions.
#
# Build:
#   docker build -t rg-divine-backend .
#
# Run (with env file):
#   docker run --env-file .env -p 3000:3000 rg-divine-backend
#

FROM node:20-alpine AS deps
WORKDIR /app
COPY backend/package*.json ./
RUN npm ci --only=production

# ── Build stage ───────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY backend/package*.json ./
RUN npm ci
COPY backend/ .
RUN npm run build 2>/dev/null || true   # Skip if no build step

# ── Production stage ──────────────────────────────────────────────────────────
FROM node:20-alpine AS production
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Copy production deps
COPY --from=deps /app/node_modules ./node_modules

# Copy source (or built output if applicable)
COPY backend/ .

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
