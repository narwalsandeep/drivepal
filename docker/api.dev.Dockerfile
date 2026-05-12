# NestJS development — `nest start --watch` with bind-mounted `./api` (see docker-compose.yml).
# Build context: repository root (`.`).

FROM node:20-alpine
WORKDIR /app

COPY api/package.json api/package-lock.json* ./
RUN npm ci

COPY api/ ./
COPY docker/api-entrypoint-dev.sh /usr/local/bin/api-entrypoint-dev.sh
RUN chmod +x /usr/local/bin/api-entrypoint-dev.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/api-entrypoint-dev.sh"]
CMD ["npm", "run", "start:dev"]
