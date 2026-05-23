#!/usr/bin/env bash
set -u

qs_dir="$HOME/.config/quickshell/dashboard"
asset_installer="$HOME/.config/scripts/install-dashboard-assets.sh"
log_file="/tmp/qs-dashboard.log"
asset_log="/tmp/qs-dashboard-assets.log"
lock_file="/tmp/qs-dashboard.lock"

exec 9>"$lock_file"
if ! flock -n 9; then
    echo "$(date '+%F %T') dashboard launcher is already running; ignoring duplicate hotkey" >>"$log_file"
    exit 0
fi

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
}

if ! have qs; then
    log "ERROR: qs command not found"
    exit 1
fi

if [[ -f "$asset_installer" ]]; then
    bash "$asset_installer" >"$asset_log" 2>&1 || true
fi

mapfile -t pids < <(dashboard_pids)

if (( ${#pids[@]} > 1 )); then
    log "WARNING: found multiple dashboard qs instances: ${pids[*]}; killing all and restarting one"
    kill_dashboard
    sleep 0.2
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
    log "ERROR: dashboard IPC failed or timed out; killing dashboard instance to avoid frozen overlay"
    kill_dashboard
    exit 1
fi
