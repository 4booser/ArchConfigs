#!/usr/bin/env bash
set -euo pipefail

qs_dir="$HOME/.config/quickshell/dashboard"
asset_installer="$HOME/.config/scripts/install-dashboard-assets.sh"
log_file="/tmp/qs-dashboard.log"
asset_log="/tmp/qs-dashboard-assets.log"

if [[ -f "$asset_installer" ]]; then
    bash "$asset_installer" >"$asset_log" 2>&1 || true
fi

if ! pgrep -f "qs.*-p[[:space:]]+$qs_dir" >/dev/null 2>&1; then
    qs -p "$qs_dir" >"$log_file" 2>&1 &
    sleep 0.45
fi

qs -p "$qs_dir" ipc call dashboard toggle
