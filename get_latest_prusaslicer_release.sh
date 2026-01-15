#!/bin/bash
# PrusaSlicer Release Fetcher
# Uses Community AppImage repo since official PrusaSlicer stopped providing AppImages in 2.9.0+
# Source: https://github.com/probonopd/PrusaSlicer.AppImage

TMPDIR="$(mktemp -d)"
GITHUB_API="https://api.github.com/repos/probonopd/PrusaSlicer.AppImage/releases/latest"

curl -SsL "$GITHUB_API" > "$TMPDIR/latest.json"

# Get the x86_64 AppImage (not the .zsync file)
url=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .browser_download_url' "$TMPDIR/latest.json")
name=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .name' "$TMPDIR/latest.json")
version=$(jq -r '.tag_name' "$TMPDIR/latest.json")

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
