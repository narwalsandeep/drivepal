# Angular dev server — live reload; bind-mounted `./ui`. Proxy → `http://api:3000`.
# Build context: repository root (`.`).

FROM node:20-alpine
WORKDIR /app

COPY ui/package.json ui/package-lock.json* ./
RUN npm ci

COPY ui/ ./
COPY docker/ui-entrypoint-dev.sh /usr/local/bin/ui-entrypoint-dev.sh
RUN chmod +x /usr/local/bin/ui-entrypoint-dev.sh

EXPOSE 4200
ENTRYPOINT ["/usr/local/bin/ui-entrypoint-dev.sh"]
CMD ["npx", "ng", "serve", "--host", "0.0.0.0", "--port", "4200", "--proxy-config", "proxy.conf.docker.json", "--configuration", "development", "--poll", "2000"]
