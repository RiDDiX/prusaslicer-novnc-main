# PrusaSlicer noVNC Docker Container (Enhanced Fork)

> **🍴 This is a fork of [helfrichmichael/prusaslicer-novnc](https://github.com/helfrichmichael/prusaslicer-novnc)**

## What's Different in This Fork?

This enhanced fork adds the following improvements:

- **🔄 Automatic PrusaSlicer Updates** - Container automatically updates PrusaSlicer to the latest version on startup
- **⏰ Periodic Update Checks** - Optional background service to check for updates regularly
- **🎮 Intel iGPU Support** - Added support for Intel integrated graphics (in addition to Nvidia)
- **📦 GitHub Container Registry** - Images hosted on ghcr.io instead of Docker Hub
- **🛠️ Improved CI/CD** - Automatic builds on push and scheduled weekly builds
- **📥 Community AppImage** - Uses [probonopd/PrusaSlicer.AppImage](https://github.com/probonopd/PrusaSlicer.AppImage) since official PrusaSlicer stopped providing AppImages in v2.9.0+
- **⬆️ Updated Dependencies** - VirtualGL 3.1.4, TurboVNC 3.2.1 (latest stable versions)

## Overview

This is a noVNC build using supervisor to serve PrusaSlicer in your favorite web browser. This was primarily built for users using the [popular unraid NAS software](https://unraid.net), to allow them to quickly hop in a browser, slice, and upload their favorite 3D prints.

Based on the original work by:
- [helfrichmichael/prusaslicer-novnc](https://github.com/helfrichmichael/prusaslicer-novnc) (upstream)
- [dmagyar/prusaslicer-vnc-docker](https://hub.docker.com/r/dmagyar/prusaslicer-vnc-docker/)

## How to use

### In unraid

If you're using unraid, open your Docker page and under `Template repositories`, add `https://github.com/helfrichmichael/unraid-templates` and save it. You should then be able to Add Container for prusaslicer-novnc. For unraid, the template will default to 6080 for the noVNC web instance.

### Outside of unraid

#### Docker
To run this image, you can run the following command: 
```bash
docker run --detach \
  --volume=prusaslicer-novnc-data:/configs/ \
  --volume=prusaslicer-novnc-prints:/prints/ \
  -p 8080:8080 \
  -e SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt" \
  --name=prusaslicer-novnc \
  ghcr.io/YOUR-USERNAME/prusaslicer-novnc:latest
```

Replace `YOUR-USERNAME` with your GitHub username.

This will bind `/configs/` in the container to a local volume on my machine named `prusaslicer-novnc-data`. Additionally it will bind `/prints/` in the container to `prusaslicer-novnc-prints` locally on my machine, it will bind port `8080` to `8080`, and finally, it will provide an environment variable to keep Prusaslicer happy by providing an `SSL_CERT_FILE`.

#### Docker Compose
To use the pre-built image, simply clone this repository or copy `docker-compose.yml` and run `docker compose up -d`.

To build a new image, clone this repository and run `docker compose up -f docker-compose.build.yml --build -d`

### Using a VNC Viewer

To use a VNC viewer with the container, the default port for TurobVNC is 5900. You can add this port by adding `-p 5900:5900` to your command to start the container to open this port for access. See note below about ports related to `VNC_PORT` environment variable. 


### GPU Acceleration/Passthrough

This container supports hardware 3D acceleration with both **Nvidia GPUs** and **Intel integrated graphics (iGPU)**.

#### Nvidia GPU

Pass your Nvidia GPU into the container using environment variables:

```bash
docker run --detach \
  --runtime=nvidia \
  -e NVIDIA_VISIBLE_DEVICES=all \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e ENABLEHWGPU=true \
  ...
```

In unraid, add `--runtime=nvidia` to "Extra Parameters".

Verify GPU usage with `nvidia-smi -l` on the host:
```
+---------------------------------------------------------------------------------------+
| Processes:                                                                            |
|  GPU   GI   CI        PID   Type   Process name                            GPU Memory |
|=======================================================================================|
|    0   N/A  N/A   4129827      G   /slic3r/slic3r-dist/bin/prusa-slicer        262MiB |
+---------------------------------------------------------------------------------------+
```

#### Intel iGPU

For Intel integrated graphics, pass the render device into the container:

```bash
docker run --detach \
  --device=/dev/dri:/dev/dri \
  -e ENABLEHWGPU=true \
  -e VGL_DISPLAY=egl \
  ...
```

**Docker Compose for Intel iGPU:**
```yaml
services:
  prusaslicer-novnc:
    devices:
      - /dev/dri:/dev/dri
    environment:
      - ENABLEHWGPU=true
      - VGL_DISPLAY=egl
```

Verify Intel GPU is available:
```bash
docker exec prusaslicer-novnc ls -la /dev/dri
```

#### Verifying GPU Acceleration

The `GL Version` on the System Information screen inside PrusaSlicer should show your GPU model and driver version:

<img src="https://github.com/vajonam/prusaslicer-novnc/assets/152501/250c93f5-e550-42f9-8cce-b942c93ef61e" width="300" />



### Auto-Update Feature

This container supports automatic updates of PrusaSlicer. By default, the container checks for updates every time it starts and will automatically download and install the latest version if available.

#### Update Behavior

- **On Container Start**: When `AUTO_UPDATE=true` (default), the container checks GitHub for the latest PrusaSlicer release and updates if a newer version is available.
- **Periodic Updates**: When `ENABLE_PERIODIC_UPDATES=true`, a background process checks for updates at regular intervals (default: every 24 hours).
- **Manual Updates**: You can manually trigger an update by running: `docker exec prusaslicer-novnc /slic3r/update_prusaslicer.sh check`

#### Update Environment Variables

- `AUTO_UPDATE=true`: Check for updates on container start (default: `true`)
- `ENABLE_PERIODIC_UPDATES=false`: Enable background periodic update checks (default: `false`)
- `UPDATE_CHECK_INTERVAL=86400`: Interval in seconds between periodic checks (default: 86400 = 24 hours)

**Note**: After an update, PrusaSlicer will automatically restart with the new version. Your configurations in `/configs/` are preserved.

### Other Environment Variables

Below are the default values for various environment variables:

- `DISPLAY=:0`: Sets the DISPLAY variable (usually left as 0).
- `SUPD_LOGLEVEL=INFO`: Specifies the log level for supervisord. Set to `TRACE` to see output for various commands helps if you are debugging something. See superviosrd manual for possible levels.
- `ENABLEHWGPU=`: Enables HW 3D acceleration. Default is `false` to maintain backward compatability.
- `VGL_DISPLAY=egl`: Advanced setting to target specific cards if you have multiple GPUs
- `NOVNC_PORT=8080`: Sets the port for the noVNC HTML5/web interface.
- `VNC_RESOLUTION=1280x800`: Defines the resolution of the VNC server.
- `VNC_PASSWORD=`: Defaults to no VNC password, but you can add one here.
- `VNC_PORT=5900`: Defines the port for the VNC server, allowing direct connections using a VNC client. Note that the `DISPLAY` number is added to the port number (e.g., if your display is :1, the VNC port accepting connections will be `5901`).

## Links

- [PrusaSlicer](https://www.prusa3d.com/prusaslicer/)
- [TurboVNC](https://www.turbovnc.org/)
- [VirtualGL](https://virtualgl.org/)
- [Supervisor](http://supervisord.org/)

## Credits & Original Project

This project is a fork with enhancements. Please support the original authors:

- **Original Repository**: [helfrichmichael/prusaslicer-novnc](https://github.com/helfrichmichael/prusaslicer-novnc)
- **Original Docker Hub**: [mikeah/prusaslicer-novnc](https://hub.docker.com/r/mikeah/prusaslicer-novnc)

<a href="https://www.buymeacoffee.com/helfrichmichael" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee (Original Author)" height="41" width="174"></a>
