#!/usr/bin/env bash
set -u

# Manual dashboard test launcher.
# This is intentionally separate from the SUPER+M hotkey path.
# It enables the experimental Quickshell dashboard for one explicit run.

export QS_DASHBOARD_ENABLE=1
exec "$HOME/.config/hypr/scripts/dashboard.sh"
