#!/usr/bin/env bash

set -u

if ! command -v hyprswitch >/dev/null 2>&1; then
    exit 0
fi

if pgrep -x hyprswitch >/dev/null 2>&1; then
    exit 0
fi

css="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprswitch.css"

setsid -f hyprswitch init \
    --show-title \
    --size-factor 5.8 \
    --workspaces-per-row 5 \
    --custom-css "$css" \
    >/tmp/hyprswitch.log 2>&1
