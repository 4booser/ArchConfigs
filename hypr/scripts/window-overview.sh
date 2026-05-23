#!/usr/bin/env bash
set -euo pipefail

HYPR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS="$HYPR_DIR/hyprswitch.css"

if command -v hyprswitch >/dev/null 2>&1; then
    if ! pgrep -x hyprswitch >/dev/null 2>&1; then
        hyprswitch init --show-title --size-factor 5.8 --workspaces-per-row 5 --custom-css "$CSS" >/dev/null 2>&1 &
        sleep 0.25
    fi

    exec hyprswitch gui --mod-key super --key t
fi

notify-send "Window Overview" "Install hyprswitch: yay -S hyprswitch" 2>/dev/null || true
exec "$HYPR_DIR/scripts/control-center-rofi.sh"
