#!/usr/bin/env bash
# Build a universal Android APK locally. By default publish it to the Latest GitHub release.
# Needs: Flutter >= 3.27, JDK 17 + Android SDK, firebase.env, and gh for publishing.
#   ./tool/build_release.sh              # publish build/latest.apk to v<version>
#   ./tool/build_release.sh --no-publish # keep build/latest.apk locally
set -euo pipefail
cd "$(dirname "$0")/.."

if (( $# > 1 )) || [[ $# == 1 && $1 != --no-publish ]]; then
  echo "Usage: $0 [--no-publish]" >&2; exit 2
fi
[ -f firebase.env ] || { echo "Copy firebase.env.example to firebase.env first. The hosted backend works without Firebase settings."; exit 1; }
if grep -q '^API_URL=.' firebase.env && ! grep -q '^API_URL=https://' firebase.env; then
  echo "WARNING: Use an HTTPS API_URL for release builds, or leave it empty to use the hosted backend."
fi
[ -d android ] || ./tool/setup_platforms.sh

flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release --dart-define-from-file=firebase.env

cp build/app/outputs/flutter-apk/app-release.apk build/latest.apk
echo "Built build/latest.apk ($(du -h build/latest.apk | cut -f1))"

if [[ ${1:-} != --no-publish ]]; then
  ./tool/publish_apk.sh
fi
