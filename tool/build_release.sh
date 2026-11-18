#!/usr/bin/env bash
# Builds the release APK on THIS machine and publishes it as a GitHub *pre-release* with the GitHub CLI.
# Needs: Flutter >= 3.27, JDK 17 + Android SDK, `gh auth login`, and a filled-in firebase.env.
# No GitHub Actions: run it yourself (a laptop or a GitHub Codespace works).
#   ./tool/build_release.sh            # builds, then publishes tag v<version>-pre
#   ./tool/build_release.sh --no-publish
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f firebase.env ] || { echo "Copy firebase.env.example to firebase.env first. The hosted backend works without Firebase settings."; exit 1; }
if grep -q '^API_URL=.' firebase.env && ! grep -q '^API_URL=https://' firebase.env; then
  echo "WARNING: Use an HTTPS API_URL for release builds, or leave it empty to use the hosted backend."
fi
[ -d android ] || ./tool/setup_platforms.sh

flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=firebase.env

VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d+ -f1)"
BUILD="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -s -d+ -f2)"
TAG="v${VERSION}-pre"
APK="build/smartbell-${VERSION}-pre.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$APK"
echo "Built $APK ($(du -h "$APK" | cut -f1))"

[ "${1:-}" = "--no-publish" ] && exit 0
command -v gh >/dev/null || { echo "Install the GitHub CLI (gh) to publish, or upload $APK to a release by hand."; exit 1; }
gh release create "$TAG" "$APK" --repo mozack777/SmartBell-App --prerelease \
  --title "SmartBell ${VERSION} (pre-release)" \
  --notes "Pre-release build ${VERSION}+${BUILD:-1} for testing. Signed with the debug key unless android/key.properties is configured, so it is not for the Play Store. Install on Android: allow 'install unknown apps', then open the APK."
echo "Published pre-release $TAG"
