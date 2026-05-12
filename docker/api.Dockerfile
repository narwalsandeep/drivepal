# NestJS production image — build context must be `api/` (package.json + Nest app at repo root of service).
# Expects `npm run build` to produce `dist/` and `node dist/main.js` (or set CMD to match your entry).
# Compose supplies DATABASE_URL; enable CORS for the Angular origin if the browser calls the API directly (non–same-origin).

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main.js"]
