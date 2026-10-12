#!/usr/bin/env bash
set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RECORDINGS="${RECORDINGS:-$PROJECT_ROOT/recordings}"
RETENTION_MINUTES="${RETENTION_MINUTES:-4320}"

mkdir -p "$RECORDINGS"

# The recorder maintains the rolling HLS archive itself. This removes legacy
# MP4 recordings from the previous implementation after the same three days.
find "$RECORDINGS" \
  -type f \
  -name '*.mp4' \
  -mmin "+$RETENTION_MINUTES" \
  -delete
