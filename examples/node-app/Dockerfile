# =============================================================================
# Stage 1: Build Stage (if TypeScript or build step needed)
# =============================================================================
FROM node:20-alpine AS builder

WORKDIR /build

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# If you have a build step (TypeScript, etc.), uncomment:
# RUN npm run build

# =============================================================================
# Stage 2: Production Runtime
# =============================================================================
FROM node:20-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Note: node:20-alpine image already has 'node' user with UID 1000 and GID 1000
# We'll use that existing user instead of creating a new one

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ONLY production dependencies
# Note: yarn is already included in node:20-alpine base image
RUN npm install -g pm2 \
    && npm install --only=production \
    && npm cache clean --force

# Copy application code
COPY --chown=node:node . .

# If you had a build step, copy built files:
# COPY --from=builder --chown=appuser:appuser /build/dist ./dist

# Switch to non-root user (node user already exists in base image)
USER node

# Expose application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "server.js"]
