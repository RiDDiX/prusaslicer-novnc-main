#!/bin/bash
# Periodic PrusaSlicer Update Check
# Runs in background and checks for updates at specified intervals

UPDATE_INTERVAL="${UPDATE_CHECK_INTERVAL:-86400}"  # Default: 24 hours (in seconds)
LOG_PREFIX="[Periodic-Update]"

log() {
    echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting periodic update checker (interval: ${UPDATE_INTERVAL}s)"

while true; do
    sleep "$UPDATE_INTERVAL"
    
    log "Running scheduled update check..."
    
    # Check for updates
    if /slic3r/update_prusaslicer.sh check; then
        # Check if update was actually performed by comparing versions
        NEW_VERSION=$(/slic3r/update_prusaslicer.sh version)
        log "Current version after check: $NEW_VERSION"
    else
        log "Update check failed"
    fi
done
