#!/usr/bin/env bash
set -u

CAMERA_URL="${CAMERA_URL:-http://192.168.1.241:81/stream}"
RECORDINGS="${RECORDINGS:-/home/nf-box/Projects/camera/recordings}"
LIVE="${LIVE:-/home/nf-box/Projects/camera/web/live}"

mkdir -p "$RECORDINGS" "$LIVE"

# Encode once and send the same H.264 packets to both outputs. Fragmented
# MP4 commits each keyframe interval without waiting for the clip to close.
outputs="[f=segment:segment_format=mp4:segment_time=3600:segment_atclocktime=1:reset_timestamps=1:strftime=1:segment_format_options=movflags=+frag_keyframe+empty_moov+default_base_moof]$RECORDINGS/%Y-%m-%d_%H-%M-%S.mp4"
outputs+="|[f=hls:hls_time=0.8:hls_list_size=8:hls_delete_threshold=4:hls_start_number_source=epoch:hls_flags=delete_segments+omit_endlist+independent_segments+temp_file:hls_segment_filename=$LIVE/segment_%d.ts]$LIVE/live.m3u8"

child=""
stopping=0
stop_capture() {
    stopping=1
    if [[ -n "$child" ]]; then
        kill -TERM "$child" 2>/dev/null || true
    fi
}
trap stop_capture TERM INT

while (( ! stopping )); do
    echo "$(date): Starting camera stream"

    # MJPEG has no capture timestamps. Preserve arrival timing instead of
    # treating every received frame as 1/25 second of video.
    ffmpeg \
        -nostdin -hide_banner -loglevel warning \
        -f mjpeg -use_wallclock_as_timestamps 1 \
        -fflags nobuffer -flags low_delay \
        -probesize 1000000 -analyzeduration 0 \
        -rw_timeout 10000000 -i "$CAMERA_URL" \
        -map 0:v -an \
        -c:v libx264 -preset veryfast -tune zerolatency \
        -crf 23 -pix_fmt yuv420p -vf fps=10 -fps_mode cfr \
        -force_key_frames 'expr:gte(t,n_forced*0.5)' \
        -flags +global_header \
        -f tee "$outputs" &
    child=$!
    wait "$child" || true
    if (( stopping )); then
        wait "$child" 2>/dev/null || true
        break
    fi
    child=""
    echo "$(date): Camera disconnected. Retrying in 5 seconds..."
    sleep 5 &
    child=$!
    wait "$child" || true
    child=""
done
