#!/usr/bin/env bash
# Publish the tested, universal APK. Called both by Actions and by build_release.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

apk=build/latest.apk
[[ -s "$apk" ]] || { echo "Missing or empty $apk; build it before publishing." >&2; exit 1; }
version=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
tag=${1:-v${version%%+*}}
if [[ "$tag" != v* ]] || ! git check-ref-format "refs/tags/$tag"; then
  echo "Expected a valid v-prefixed release tag." >&2
  exit 1
fi

# Don't attach a new commit's binary to a release whose source tag points elsewhere.
commit=$(git rev-parse HEAD)
tag_commit=$(git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}" | awk 'END {print $1}')
if [[ -n "$tag_commit" && "$tag_commit" != "$commit" ]]; then
  echo "$tag already points to another commit. Build that tag or publish a new version." >&2
  exit 1
fi

title="SmartBell $tag"
if gh release view "$tag" >/dev/null 2>&1; then
  gh release upload "$tag" "$apk" --clobber
  # Migrate older APK filenames on this release only, after the replacement was uploaded.
  old_apks=$(gh release view "$tag" --json assets --jq '.assets[].name | select(. != "latest.apk" and (ascii_downcase | endswith(".apk")))')
  while IFS= read -r name; do
    [[ -z "$name" ]] || gh release delete-asset "$tag" --yes -- "$name"
  done <<< "$old_apks"
  gh release edit "$tag" --title "$title" --draft=false --prerelease=false --latest
else
  gh release create "$tag" "$apk" --target "$commit" --title "$title" --latest \
    --notes "Download latest.apk to install SmartBell $version on Android. This is a universal APK for sideloading. GitHub Actions builds are debug-signed for testing, not for the Play Store."
fi
