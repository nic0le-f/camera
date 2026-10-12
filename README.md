# Camera dashboard and 72-hour recorder

This project records an ESP32 MJPEG camera and provides a private dashboard
with a low-delay live feed and a continuous, seekable 72-hour history.

The recording is stored as one-minute HLS segments rather than giant video
files. This is intentional: a restart or damaged file can only affect a small
piece, while the dashboard still presents the pieces as one recording with a
single wall-clock timeline. FFmpeg automatically removes segments after they
fall out of the 72-hour rolling window.

The dashboard listens only on `http://127.0.0.1:8080/` and is published
privately with Tailscale Serve. The scripts derive their paths from the
repository, so the project can be moved or installed without editing source
files.

Machine-specific settings are deliberately kept out of Git. The installer
stores the real camera address and retention settings in
`/etc/camera-recorder.env`; the repository contains only an example template.

## Install

Ubuntu needs FFmpeg and Nginx. Tailscale is already installed on this machine,
but its daemon and account still need to be enabled.

```bash
sudo apt update
sudo apt install ffmpeg nginx
sudo "$(pwd)/scripts/install.sh"
```

Edit `/etc/camera-recorder.env` and replace `CAMERA_IP` with the camera's local
IP address, then run:

```bash
sudo systemctl restart camera-recorder.service
```

Check the local dashboard at `http://127.0.0.1:8080/`. Once that works, connect
Tailscale and publish the loopback-only site to the tailnet:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
sudo tailscale serve --bg http://127.0.0.1:8080
tailscale serve status
```

The last command prints the private HTTPS address to open on another device in
the same tailnet.

## Operation

```bash
systemctl status camera-recorder.service
journalctl -u camera-recorder.service -n 50 --no-pager
sudo systemctl restart camera-recorder.service
```

Configuration lives in `/etc/camera-recorder.env`:

- `CAMERA_URL`: MJPEG stream URL.
- `ARCHIVE_HOURS`: rolling retention window; default `72`.
- `ARCHIVE_SEGMENT_SECONDS`: internal segment length; default `60`.

Changing the retention setting affects new manifest updates after the recorder
is restarted. The archive requires roughly three times the storage used in one
day; actual usage depends on scene detail and the camera resolution.

## Files

- `scripts/camera-recorder.sh`: one H.264 encode feeding live and archive HLS.
- `scripts/install.sh`: renders machine-specific Nginx and systemd files.
- `scripts/camera-cleanup.sh`: removes old MP4 files from the former recorder.
- `web/index.html`: dashboard and wall-clock archive timeline.
- `config/`: service, Nginx, and environment templates.
