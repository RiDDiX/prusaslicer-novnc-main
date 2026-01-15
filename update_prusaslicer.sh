#!/bin/bash
# PrusaSlicer Auto-Update Script
# Checks for new versions and updates if available
# Uses Community AppImage repo: https://github.com/probonopd/PrusaSlicer.AppImage

set -e

SLIC3R_DIR="/slic3r"
VERSION_FILE="/slic3r/.current_version"
LOG_PREFIX="[PrusaSlicer-Update]"

# Default to own repo, can be overridden via environment variable
DEFAULT_REPO="riddix/prusaslicer-novnc-main"
APPIMAGE_REPO="${PRUSASLICER_APPIMAGE_REPO:-$DEFAULT_REPO}"
GITHUB_API="https://api.github.com/repos/${APPIMAGE_REPO}/releases"

log() {
    echo "$LOG_PREFIX $1"
}

get_installed_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

get_latest_release_info() {
    TMPDIR="$(mktemp -d)"
    
    # Get releases and find the latest one that has an AppImage (skip docker-* tags)
    curl -SsL --connect-timeout 10 --max-time 30 "$GITHUB_API" 2>/dev/null | \
        jq -r '[.[] | select(.assets[].name | test("AppImage$"))] | first' > "$TMPDIR/latest.json"
    
    # If no AppImage release found, try community repo as fallback
    if [ ! -s "$TMPDIR/latest.json" ] || [ "$(cat "$TMPDIR/latest.json")" = "null" ]; then
        log "No AppImage in own repo, falling back to community repo..."
        curl -SsL --connect-timeout 10 --max-time 30 "https://api.github.com/repos/probonopd/PrusaSlicer.AppImage/releases/latest" 2>/dev/null > "$TMPDIR/latest.json"
    fi
    
    LATEST_URL=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .browser_download_url' "$TMPDIR/latest.json" 2>/dev/null)
    LATEST_NAME=$(jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .name' "$TMPDIR/latest.json" 2>/dev/null)
    LATEST_VERSION=$(jq -r '.tag_name' "$TMPDIR/latest.json" 2>/dev/null)
    
    rm -rf "$TMPDIR"
}

download_and_install() {
    log "Downloading PrusaSlicer $LATEST_VERSION..."
    
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
    
    # Download the AppImage
    curl -sSL "$LATEST_URL" -o "$LATEST_NAME"
    chmod +x "$LATEST_NAME"
    
    # Extract AppImage
    log "Extracting AppImage..."
    "./$LATEST_NAME" --appimage-extract
    
    # Backup old version (if exists)
    if [ -d "$SLIC3R_DIR/squashfs-root" ]; then
        log "Backing up old version..."
        rm -rf "$SLIC3R_DIR/squashfs-root.bak"
        mv "$SLIC3R_DIR/squashfs-root" "$SLIC3R_DIR/squashfs-root.bak"
    fi
    
    # Move new version into place
    log "Installing new version..."
    mv squashfs-root "$SLIC3R_DIR/"
    
    # Update version file
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    
    # Cleanup
    cd /
    rm -rf "$TMPDIR"
    
    # Remove backup after successful install
    rm -rf "$SLIC3R_DIR/squashfs-root.bak"
    
    log "Update to $LATEST_VERSION completed successfully!"
    return 0
}

check_and_update() {
    log "Checking for updates..."
    
    INSTALLED_VERSION=$(get_installed_version)
    get_latest_release_info
    
    log "Installed version: $INSTALLED_VERSION"
    log "Latest version: $LATEST_VERSION"
    
    if [ "$INSTALLED_VERSION" = "$LATEST_VERSION" ]; then
        log "Already up to date."
        return 0
    fi
    
    if [ -z "$LATEST_URL" ] || [ "$LATEST_URL" = "null" ]; then
        log "ERROR: Could not find download URL for latest release."
        return 1
    fi
    
    log "New version available! Updating from $INSTALLED_VERSION to $LATEST_VERSION..."
    download_and_install
}

# Main execution
case "${1:-check}" in
    check)
        check_and_update
        ;;
    force)
        log "Forcing update..."
        get_latest_release_info
        download_and_install
        ;;
    version)
        get_installed_version
        ;;
    latest)
        get_latest_release_info
        echo "$LATEST_VERSION"
        ;;
    *)
        echo "Usage: $0 {check|force|version|latest}"
        exit 1
        ;;
esac
