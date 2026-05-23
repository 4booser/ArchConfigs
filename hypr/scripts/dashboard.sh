#!/usr/bin/env bash
set -euo pipefail

qs_dir="$HOME/.config/quickshell/dashboard"
asset_installer="$HOME/.config/scripts/install-dashboard-assets.sh"

if [[ -x "$asset_installer" ]]; then
    "$asset_installer" >/tmp/qs-dashboard-assets.log 2>&1 || true
fi

if ! pgrep -f "qs.*-p $qs_dir" >/dev/null 2>&1; then
    qs -p "$qs_dir" >/tmp/qs-dashboard.log 2>&1 &
    sleep 0.35
fi

qs -p "$qs_dir" ipc call dashboard toggle
