#!/usr/bin/env bash
set -u

qs_dir="$HOME/.config/quickshell/dashboard"
log_file="/tmp/qs-dashboard.log"

log() {
    echo "$(date '+%F %T') $*" >>"$log_file" 2>/dev/null || true
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
    sleep 0.15
    dashboard_pids | xargs -r kill -9 2>/dev/null || true
}

call_ipc() {
    timeout 1.5s qs -p "$qs_dir" ipc call dashboard toggle >>"$log_file" 2>&1
}

start_dashboard() {
    : >"$log_file"
    log "starting qs dashboard from $qs_dir"
    qs -p "$qs_dir" >>"$log_file" 2>&1 &
    sleep 0.55
}

if [[ "${1:-}" == "--kill" ]]; then
    kill_dashboard
    log "killed dashboard by explicit --kill"
    exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
    dashboard_pids || true
    exit 0
fi

if [[ "${1:-}" == "--restart" ]]; then
    kill_dashboard
    start_dashboard
    call_ipc || true
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

mapfile -t pids < <(dashboard_pids)

if (( ${#pids[@]} > 1 )); then
    log "multiple dashboard instances: ${pids[*]}; restarting cleanly"
    kill_dashboard
    pids=()
fi

if (( ${#pids[@]} == 0 )); then
    start_dashboard
fi

log "toggle request"
if call_ipc; then
    exit 0
fi

log "IPC failed; restarting once"
kill_dashboard
start_dashboard
if call_ipc; then
    exit 0
fi

log "ERROR: IPC failed after restart"
kill_dashboard
exit 1
