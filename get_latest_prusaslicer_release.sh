#!/bin/bash
# PrusaSlicer Release Fetcher
# Default: Own repo (RiDDiX/prusaslicer-novnc-main) AppImage releases
# Fallback: Community repo (probonopd/PrusaSlicer.AppImage)

TMPDIR="$(mktemp -d)"

# Default to own repo, can be overridden via environment variable
DEFAULT_REPO="riddix/prusaslicer-novnc-main"
APPIMAGE_REPO="${PRUSASLICER_APPIMAGE_REPO:-$DEFAULT_REPO}"
GITHUB_API="https://api.github.com/repos/${APPIMAGE_REPO}/releases"

# Get releases and find the latest one that has an AppImage (skip docker-* tags)
curl -SsL --connect-timeout 10 --max-time 30 "$GITHUB_API" 2>/dev/null | \
    jq -r '[.[] | select(.assets[].name | test("AppImage$"))] | first' > "$TMPDIR/latest.json"

# If no AppImage release found, try community repo as fallback
if [ ! -s "$TMPDIR/latest.json" ] || [ "$(cat "$TMPDIR/latest.json")" = "null" ]; then
    GITHUB_API="https://api.github.com/repos/probonopd/PrusaSlicer.AppImage/releases/latest"
    curl -SsL --connect-timeout 10 --max-time 30 "$GITHUB_API" 2>/dev/null > "$TMPDIR/latest.json"
fi

# Get the x86_64 AppImage (not the .zsync file)
url=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .browser_download_url' "$TMPDIR/latest.json" 2>/dev/null)
name=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .name' "$TMPDIR/latest.json" 2>/dev/null)
version=$(jq -r '.tag_name' "$TMPDIR/latest.json" 2>/dev/null)

# Cleanup temp directory
rm -rf "$TMPDIR"

if [ $# -ne 1 ]; then
  echo "Wrong number of params"
  exit 1
else
  request=$1
fi

case $request in
  url)
    echo "$url"
    ;;
  name)
    echo "$name"
    ;;
  version)
    echo "$version"
    ;;
  *)
    echo "Unknown request"
    exit 1
    ;;
esac

exit 0
