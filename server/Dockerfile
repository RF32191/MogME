# --- Build stage: compile TypeScript with full deps ---
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# --- Runtime stage: prod deps + compiled output only ---
FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
# Railway injects PORT; the server reads it (defaults to 8787 locally).
EXPOSE 8787
CMD ["node", "dist/index.js"]
