# Camera viewer and recorder

On this computer, open http://localhost:8080/. Nginx listens on loopback only.
The camera supplies MJPEG at http://192.168.1.241:81/stream. Use the viewer
while recording; opening another stream directly may contend with the recorder.

The recorder uses frame arrival timestamps because MJPEG supplies no capture
clock. Assuming 25 fps compresses elapsed time when the camera sends fewer
frames and makes a live player repeatedly exhaust its buffer.

One H.264 encoder supplies both the HLS viewer and recordings at the camera's
native resolution. A fixed 10 fps output repeats frames as needed to keep a
continuous timeline when the camera sends frames irregularly; it does not
create additional motion detail. The player targets about three seconds behind the published
live edge; capture, encoding and network time add to that. Variable camera frame
rate can still produce choppy motion. Returning to the tab catches up to live.

Recordings are fragmented MP4 files cut at five-minute wall-clock boundaries.
The initial clip can be shorter. Completed fragments are readable before the
clip closes and remain recoverable after interruption; the last incomplete
fragment can be lost. Existing recordings keep their original format and timing.
The cleanup script retains approximately 48 hours, running hourly.

Files:

- `scripts/camera-recorder.sh`: capture, one H.264 encode, HLS and MP4 output.
- `scripts/camera-cleanup.sh`: existing retention policy.
- `web/index.html`: live player and recordings link.
- `config/nginx-camera.conf`: loopback viewer configuration.

After recorder changes, run `sudo systemctl restart camera-recorder.service`.
After player changes, refresh the browser (Ctrl+Shift+R if needed).
Check `journalctl -u camera-recorder.service -n 30 --no-pager` for failures.

The recorder accepts CAMERA_URL, RECORDINGS and LIVE environment overrides.
Keep output paths free of FFmpeg tee option delimiters (`|`, `:`, `[` and `]`).

Recording implementation follows FFmpeg's segment, tee and fragmented MP4
options: https://www.ffmpeg.org/ffmpeg-formats.html.
