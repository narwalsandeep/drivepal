# Angular production image — repo root build context (`.`); app lives in `ui/`.
# Production build output: `dist/ui/browser` (see `ui/angular.json` -> projects.ui.architect.build.options.outputPath).

FROM node:20-alpine AS build
WORKDIR /app
COPY ui/package.json ui/package-lock.json* ./
RUN npm ci
COPY ui/ .
# Use `ng build` directly (not `npm run build`) so we do not run `prebuild` UI tests here:
# Karma needs Chrome; the slim Node image has no browser. Run `npm run test:ui` in CI before this image build.
RUN npx ng build --configuration=production

FROM nginx:1.27-alpine
COPY docker/nginx-ui.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ui/browser /usr/share/nginx/html
EXPOSE 80
