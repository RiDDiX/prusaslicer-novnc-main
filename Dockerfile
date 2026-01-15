# ORIGINAL REPO  https://github.com/damanikjosh/virtualgl-turbovnc-docker/blob/main/Dockerfile 
# FORK: https://github.com/helfrichmichael/prusaslicer-novnc
# Enhanced with: Auto-updates, Intel iGPU support, periodic update checks
ARG UBUNTU_VERSION=22.04

FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu${UBUNTU_VERSION}
LABEL authors="vajonam, Michael Helfrich - helfrichmichael"
LABEL maintainer="Fork maintainer"
LABEL description="PrusaSlicer with noVNC, auto-updates, Nvidia & Intel GPU support"

ARG VIRTUALGL_VERSION=3.1.4
ARG TURBOVNC_VERSION=3.2.1
ENV DEBIAN_FRONTEND=noninteractive

# Install some basic dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xorg xauth gosu supervisor x11-xserver-utils libegl1-mesa libgl1-mesa-glx \
    locales-all libpam0g libxt6 libxext6 dbus-x11 x11-xkb-utils xkb-data python3 xterm novnc \
    lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf arc-theme \
    freeglut3 libgtk2.0-dev libwxgtk3.0-gtk3-dev libwx-perl libxmu-dev libgl1-mesa-dri \
    xdg-utils locales pcmanfm jq curl git bzip2 gpg-agent software-properties-common \
    libwebkit2gtk-4.1-dev libfuse2 \
    mesa-utils libegl-mesa0 libgbm1 \
    && mkdir -p /usr/share/desktop-directories \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install Firefox ESR from official Mozilla repository (more reliable than PPA)
RUN install -d -m 0755 /etc/apt/keyrings \
    && wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null \
    && echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' | tee /etc/apt/preferences.d/mozilla > /dev/null \
    && apt-get update \
    && apt-get install -y firefox-esr --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install VirtualGL and TurboVNC from GitHub Releases
RUN wget -qO /tmp/virtualgl_${VIRTUALGL_VERSION}_amd64.deb https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb \
    && wget -qO /tmp/turbovnc_${TURBOVNC_VERSION}_amd64.deb https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb \
    && dpkg -i /tmp/virtualgl_${VIRTUALGL_VERSION}_amd64.deb \
    && dpkg -i /tmp/turbovnc_${TURBOVNC_VERSION}_amd64.deb \
    && rm -rf /tmp/*.deb

# Install Prusaslicer.
WORKDIR /slic3r
COPY get_latest_prusaslicer_release.sh /slic3r/
COPY update_prusaslicer.sh /slic3r/
COPY periodic_update_check.sh /slic3r/

# Fix line endings, set permissions, and download PrusaSlicer
RUN sed -i 's/\r$//' /slic3r/get_latest_prusaslicer_release.sh \
  && sed -i 's/\r$//' /slic3r/update_prusaslicer.sh \
  && sed -i 's/\r$//' /slic3r/periodic_update_check.sh \
  && chmod +x /slic3r/get_latest_prusaslicer_release.sh \
  && chmod +x /slic3r/update_prusaslicer.sh \
  && chmod +x /slic3r/periodic_update_check.sh

# Download and extract PrusaSlicer from Community AppImage repo
# (Official PrusaSlicer stopped providing AppImages since 2.9.0)
RUN set -e \
  && latestSlic3r=$(/slic3r/get_latest_prusaslicer_release.sh url) \
  && slic3rReleaseName=$(/slic3r/get_latest_prusaslicer_release.sh name) \
  && slic3rVersion=$(/slic3r/get_latest_prusaslicer_release.sh version) \
  && echo "Downloading PrusaSlicer ${slic3rVersion} from ${latestSlic3r}" \
  && curl -sSL -o "${slic3rReleaseName}" "${latestSlic3r}" \
  && chmod +x "/slic3r/${slic3rReleaseName}" \
  && "/slic3r/${slic3rReleaseName}" --appimage-extract \
  && rm -f "/slic3r/${slic3rReleaseName}" \
  && echo "${slic3rVersion}" > /slic3r/.current_version

# Create user and directories
RUN groupadd slic3r \
  && useradd -g slic3r --create-home --home-dir /home/slic3r slic3r \
  && mkdir -p /configs/.local \
  && mkdir -p /configs/.config/ \
  && mkdir -p /prints/ \
  && mkdir -p /home/slic3r/.config/ \
  && ln -s /configs/.config/ /home/slic3r/ \
  && echo "XDG_DOWNLOAD_DIR=\"/prints/\"" >> /home/slic3r/.config/user-dirs.dirs \
  && echo "file:///prints prints" >> /home/slic3r/.gtk-bookmarks \
  && chown -R slic3r:slic3r /slic3r/ /home/slic3r/ /prints/ /configs/ \
  && locale-gen en_US

# Generate key for noVNC and cleanup errors.
RUN openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/novnc.pem -out /etc/novnc.pem -days 365 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost" \
    && rm /etc/xdg/autostart/lxpolkit.desktop \
    && mv /usr/bin/lxpolkit /usr/bin/lxpolkit.ORIG

ENV PATH="${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin"

COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh \
  && sed -i 's/\r$//' /etc/supervisord.conf

# Add a default file to resize and redirect, and adjust icons for noVNC.
ADD vncresize.html /usr/share/novnc/index.html
ADD icons/prusaslicer-16x16.png /usr/share/novnc/app/images/icons/novnc-16x16.png
ADD icons/prusaslicer-24x24.png /usr/share/novnc/app/images/icons/novnc-24x24.png
ADD icons/prusaslicer-32x32.png /usr/share/novnc/app/images/icons/novnc-32x32.png
ADD icons/prusaslicer-48x48.png /usr/share/novnc/app/images/icons/novnc-48x48.png
ADD icons/prusaslicer-60x60.png /usr/share/novnc/app/images/icons/novnc-60x60.png
ADD icons/prusaslicer-64x64.png /usr/share/novnc/app/images/icons/novnc-64x64.png
ADD icons/prusaslicer-72x72.png /usr/share/novnc/app/images/icons/novnc-72x72.png
ADD icons/prusaslicer-76x76.png /usr/share/novnc/app/images/icons/novnc-76x76.png
ADD icons/prusaslicer-96x96.png /usr/share/novnc/app/images/icons/novnc-96x96.png
ADD icons/prusaslicer-120x120.png /usr/share/novnc/app/images/icons/novnc-120x120.png
ADD icons/prusaslicer-144x144.png /usr/share/novnc/app/images/icons/novnc-144x144.png
ADD icons/prusaslicer-152x152.png /usr/share/novnc/app/images/icons/novnc-152x152.png
ADD icons/prusaslicer-192x192.png /usr/share/novnc/app/images/icons/novnc-192x192.png

# Set Firefox to run with hardware acceleration as if enabled.
RUN sed -i 's|exec $MOZ_LIBDIR/$MOZ_APP_NAME "$@"|if [ -n "$ENABLEHWGPU" ] \&\& [ "$ENABLEHWGPU" = "true" ]; then\n  exec /usr/bin/vglrun $MOZ_LIBDIR/$MOZ_APP_NAME "$@"\nelse\n  exec $MOZ_LIBDIR/$MOZ_APP_NAME "$@"\nfi|g' /usr/bin/firefox-esr

VOLUME /configs/
VOLUME /prints/

ENTRYPOINT ["/entrypoint.sh"]
