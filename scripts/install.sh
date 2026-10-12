#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_USER="${SUDO_USER:-$USER}"
SERVICE_GROUP="$(id -gn "$SERVICE_USER")"

if [[ $EUID -ne 0 ]]; then
    echo "Run this installer with sudo: sudo $PROJECT_ROOT/scripts/install.sh" >&2
    exit 1
fi

install -d -o "$SERVICE_USER" -g "$SERVICE_GROUP" \
    "$PROJECT_ROOT/recordings" "$PROJECT_ROOT/web/live"

# Nginx's unprivileged worker needs to traverse the user's home directory and
# read this project, without opening the rest of the home directory to it.
setfacl -m u:www-data:x "$(dirname "$PROJECT_ROOT")"
setfacl -R -m u:www-data:rX "$PROJECT_ROOT/web" "$PROJECT_ROOT/recordings"
setfacl -R -d -m u:www-data:rX "$PROJECT_ROOT/web/live" "$PROJECT_ROOT/recordings"

render() {
    sed \
        -e "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
        -e "s|__SERVICE_USER__|$SERVICE_USER|g" \
        -e "s|__SERVICE_GROUP__|$SERVICE_GROUP|g" \
        "$1" > "$2"
}

render "$PROJECT_ROOT/config/camera-recorder.service" /etc/systemd/system/camera-recorder.service
render "$PROJECT_ROOT/config/camera-cleanup.service" /etc/systemd/system/camera-cleanup.service
install -m 0644 "$PROJECT_ROOT/config/camera-cleanup.timer" /etc/systemd/system/camera-cleanup.timer
render "$PROJECT_ROOT/config/nginx-camera.conf" /etc/nginx/sites-available/camera

if [[ ! -e /etc/camera-recorder.env ]]; then
    install -m 0644 "$PROJECT_ROOT/config/camera.env.example" /etc/camera-recorder.env
fi

ln -sfn /etc/nginx/sites-available/camera /etc/nginx/sites-enabled/camera
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl daemon-reload
systemctl enable --now nginx camera-recorder.service camera-cleanup.timer
systemctl reload nginx

echo
echo "Camera dashboard installed at http://127.0.0.1:8080/"
echo "Edit /etc/camera-recorder.env if the camera URL is different, then run:"
echo "  sudo systemctl restart camera-recorder.service"
echo "To publish it privately after Tailscale is connected:"
echo "  sudo tailscale serve --bg http://127.0.0.1:8080"
