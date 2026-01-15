#!/bin/bash
set -e
rm -f /tmp/.X*-lock
rm -f /tmp/.X11-unix/X*
export DISPLAY=${DISPLAY:-:0}
DISPLAY_NUMBER=$(echo $DISPLAY | cut -d: -f2)
export NOVNC_PORT=${NOVNC_PORT:-8080}
export VNC_PORT=${VNC_PORT:-5900}
export VNC_RESOLUTION=${VNC_RESOLUTION:-1280x800}
if [ -n "$VNC_PASSWORD" ]; then
  mkdir -p /root/.vnc
  echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd
  chmod 0600 /root/.vnc/passwd
  export VNC_SEC=
else
  export VNC_SEC="-securitytypes TLSNone,X509None,None"
fi
export LOCALFBPORT=$((${VNC_PORT} + DISPLAY_NUMBER))
if [ -n "$ENABLEHWGPU" ] && [ "$ENABLEHWGPU" = "true" ]; then
  export VGLRUN="/usr/bin/vglrun"
  export LIBGL_ALWAYS_SOFTWARE=0
else 
  export VGLRUN=
  export LIBGL_ALWAYS_SOFTWARE=1
fi

export SUPD_LOGLEVEL="${SUPD_LOGLEVEL:-TRACE}"
export VGL_DISPLAY="${VGL_DISPLAY:-egl}"

# Auto-update PrusaSlicer if enabled (default: true)
export AUTO_UPDATE="${AUTO_UPDATE:-true}"
if [ "$AUTO_UPDATE" = "true" ]; then
  echo "[Entrypoint] Checking for PrusaSlicer updates..."
  /slic3r/update_prusaslicer.sh check || echo "[Entrypoint] Update check failed, continuing with current version..."
fi

# Enable periodic updates (default: false) - set to "true" to enable background update checks
export ENABLE_PERIODIC_UPDATES="${ENABLE_PERIODIC_UPDATES:-false}"
export UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-86400}"

# fix perms and launch supervisor with the above environment variables
chown -R slic3r:slic3r /home/slic3r/ /configs/ /prints/ /slic3r/ /dev/stdout && exec gosu slic3r supervisord -e $SUPD_LOGLEVEL
