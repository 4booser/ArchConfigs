#!/usr/bin/env bash

if pgrep -f "kitty.*btop-bg" > /dev/null; then
    pkill -f "kitty.*btop-bg"
else
    kitty \
      --class btop-bg \
      --title btop-bg \
      -o background_opacity=0.42 \
      -o background_blur=20 \
      btop &
fi
