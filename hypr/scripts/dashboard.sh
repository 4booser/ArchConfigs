#!/usr/bin/env bash
set -u

qs_dir="$HOME/.config/quickshell/dashboard"
asset_installer="$HOME/.config/scripts/install-dashboard-assets.sh"
log_file="/tmp/qs-dashboard.log"
asset_log="/tmp/qs-dashboard-assets.log"
lock_file="/tmp/qs-dashboard.lock"

mkdir -p "$(dirname "$log_file")" 2>/dev/null || true

log() {
    echo "$(date '+%F %T') $*" >>"$log_file"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

dashboard_pids() {
    pgrep -af '(^|/)qs( |$)|(^|/)quickshell( |$)' 2>/dev/null \
        | awk -v dir="$qs_dir" 'index($0, "-p " dir) { print $1 }'
}

kill_dashboard() {
    dashboard_pids | xargs -r kill 2>/dev/null || true
    sleep 0.1
    dashboard_pids | xargs -r kill -9 2>/dev/null || true
}

notify_safe_mode() {
    if have notify-send; then
        notify-send "Dashboard disabled" "Safe mode: SUPER+M will not start Quickshell dashboard"
    fi
}

# SAFETY DEFAULT:
# The hotkey must not launch the experimental Quickshell overlay.
# Manual testing only:
#   QS_DASHBOARD_ENABLE=1 bash ~/.config/hypr/scripts/dashboard.sh
if [[ "${QS_DASHBOARD_ENABLE:-0}" != "1" ]]; then
    kill_dashboard
    rm -f "$lock_file"
    log "safe-mode: blocked dashboard launch; killed stale dashboard qs instances if any"
    notify_safe_mode
    exit 0
fi

exec 9>"$lock_file"
if ! flock -n 9; then
    log "launcher already running; ignoring duplicate request"
    exit 0
fi

if ! have qs; then
    log "ERROR: qs command not found"
    exit 1
fi

if [[ ! -d "$qs_dir" ]]; then
    log "ERROR: dashboard directory not found: $qs_dir"
    exit 1
fi

if [[ -f "$asset_installer" ]]; then
    bash "$asset_installer" >"$asset_log" 2>&1 || log "WARNING: asset installer failed, see $asset_log"
fi

mapfile -t pids < <(dashboard_pids)

if (( ${#pids[@]} > 1 )); then
    log "WARNING: multiple dashboard instances detected: ${pids[*]}; killing all"
    kill_dashboard
    pids=()
fi

if (( ${#pids[@]} == 0 )); then
    : >"$log_file"
    log "starting qs dashboard from $qs_dir"
    qs -p "$qs_dir" >>"$log_file" 2>&1 &

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.1
        mapfile -t pids < <(dashboard_pids)
        (( ${#pids[@]} > 0 )) && break
    done
fi

if (( ${#pids[@]} == 0 )); then
    log "ERROR: qs dashboard did not start"
    exit 1
fi

log "calling dashboard toggle on pid(s): ${pids[*]}"
if ! timeout 2s qs -p "$qs_dir" ipc call dashboard toggle >>"$log_file" 2>&1; then
    log "ERROR: dashboard IPC failed or timed out; killing dashboard instance"
    kill_dashboard
    exit 1
fi
