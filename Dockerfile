# Stage 1: Build phase
FROM node:20-alpine AS builder
WORKDIR /app

# Add build tools just in case any native Node modules need to be compiled
RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci --production

# Moved your vulnerability patches here so they are correctly bundled
RUN npm install cross-spawn@7.0.5 glob@10.5.0 minimatch@9.0.7 --production && \
    npm cache clean --force

# Stage 2: Run
FROM node:20-alpine
WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Product Service runs on 3002
EXPOSE 3002
CMD ["node", "src/server.js"]
