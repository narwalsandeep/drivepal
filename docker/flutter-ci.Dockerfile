# Optional CI image: build from repo root with `docker build -f docker/flutter-ci.Dockerfile .`
# Pin the Flutter channel/tag in CI for reproducible builds.
# Day-to-day mobile dev: use Flutter on the host (emulator/device), not this container.

FROM ghcr.io/cirruslabs/flutter:stable
WORKDIR /work
COPY app/pubspec.yaml app/pubspec.lock* ./
RUN flutter pub get
COPY app/ .
# Example pipeline steps:
# RUN flutter analyze
# RUN flutter test
# RUN flutter build apk --release
