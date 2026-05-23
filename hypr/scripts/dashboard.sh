#!/usr/bin/env bash
set -euo pipefail

script="$HOME/.config/hypr/scripts/dashboard_v2.py"

if pgrep -f "$script" >/dev/null 2>&1; then
    pkill -f "$script"
    exit 0
fi

python "$script" >/tmp/hypr-dashboard.log 2>&1 &
