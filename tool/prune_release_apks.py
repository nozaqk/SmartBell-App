"""Keep only the verified latest.apk on public GitHub releases. No tags or releases are deleted."""

import json
import subprocess
import sys

RELEASES = "repos/{owner}/{repo}/releases"


def api(endpoint, *args):
    return subprocess.check_output(["gh", "api", endpoint, *args], text=True)


def items(endpoint):
    # Decode one item per line, including all pages of both releases and assets.
    lines = api(f"{endpoint}?per_page=100", "--paginate", "--jq", ".[] | @json")
    return [json.loads(line) for line in lines.splitlines()]


def latest_apk_id(expected_tag):
    release = json.loads(api(f"{RELEASES}/latest"))
    if release["tag_name"] != expected_tag or release["draft"] or release["prerelease"]:
        raise RuntimeError(f"{expected_tag} is not the Latest release; refusing to prune")
    for asset in release["assets"]:
        if asset["name"] == "latest.apk" and asset["state"] == "uploaded" and asset["size"] > 0:
            return asset["id"]
    raise RuntimeError(f"No complete latest.apk on {expected_tag}; refusing to prune")


def prune(expected_tag):
    keep = latest_apk_id(expected_tag)
    apks = {}
    # Finish the inventory before deleting anything. Drafts aren't public downloads.
    for release in items(RELEASES):
        if release["draft"] or not release["assets"]:
            continue
        for asset in items(f"{RELEASES}/{release['id']}/assets"):
            if asset["name"].lower().endswith(".apk"):
                apks[asset["id"]] = (release["tag_name"], asset["name"])
    if keep not in apks:
        raise RuntimeError("Latest APK missing from the inventory; refusing to prune")
    del apks[keep]

    for asset_id, (tag, name) in apks.items():
        # Local publishers aren't covered by the Actions concurrency group.
        if latest_apk_id(expected_tag) != keep:
            raise RuntimeError("Latest APK changed during cleanup; stopping")
        api(f"{RELEASES}/assets/{asset_id}", "--method", "DELETE")
        print(f"Removed {tag}/{name}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 tool/prune_release_apks.py <expected-latest-tag>")
    try:
        prune(sys.argv[1])
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        sys.exit(str(exc))
