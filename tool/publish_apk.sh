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
if published=$(gh release view "$tag" --json isDraft,isPrerelease --jq '(.isDraft or .isPrerelease) | not' 2>/dev/null); then
  if [[ "$published" == true ]]; then
    latest_tag=$(gh api 'repos/{owner}/{repo}/releases/latest' --jq '.tag_name')
    if [[ "$latest_tag" != "$tag" ]]; then
      echo "$tag is superseded by $latest_tag. Use a build-only run for an older release." >&2
      exit 1
    fi
  fi
  gh release upload "$tag" "$apk" --clobber
  gh release edit "$tag" --title "$title" --draft=false --prerelease=false --latest
else
  gh release create "$tag" "$apk" --target "$commit" --title "$title" --latest \
    --notes "Download latest.apk to install SmartBell $version on Android. This is a universal APK for sideloading. GitHub Actions builds are debug-signed for testing, not for the Play Store."
fi

# Only retire older downloads after the new release and upload have succeeded.
python3 tool/prune_release_apks.py "$tag"
