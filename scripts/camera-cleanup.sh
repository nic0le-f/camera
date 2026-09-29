#!/usr/bin/env bash

RECORDINGS="/home/nf-box/Projects/camera/recordings"

find "$RECORDINGS" \
  -type f \
  -name '*.mp4' \
  -mmin +2880 \
  -delete
