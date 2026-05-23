#!/usr/bin/env bash
set -u

qs_dir="$HOME/.config/quickshell/dashboard"
log_file="/tmp/qs-dashboard.log"
lock_file="/tmp/qs-dashboard.lock"

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
    timeout 2s qs -p "$qs_dir" ipc call dashboard toggle >>"$log_file" 2>&1
}

if [[ "${1:-}" == "--kill" ]]; then
    kill_dashboard
    rm -f "$lock_file"
    log "killed dashboard by explicit --kill"
    exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
    dashboard_pids || true
    exit 0
fi

if [[ "${1:-}" == "--restart" ]]; then
    kill_dashboard
    rm -f "$lock_file"
fi

exec 9>"$lock_file"
if ! flock -n 9; then
    log "launcher already running; removing stale lock and ignoring duplicate request"
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
    log "WARNING: multiple dashboard instances detected: ${pids[*]}; killing all"
    kill_dashboard
    pids=()
fi

if (( ${#pids[@]} == 0 )); then
    : >"$log_file"
    log "starting qs dashboard from $qs_dir"
    qs -p "$qs_dir" >>"$log_file" 2>&1 &

    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        sleep 0.12
        mapfile -t pids < <(dashboard_pids)
        (( ${#pids[@]} > 0 )) && break
    done
fi

if (( ${#pids[@]} == 0 )); then
    log "ERROR: qs dashboard did not start"
    exit 1
fi

log "calling dashboard toggle on pid(s): ${pids[*]}"
if ! call_ipc; then
    log "ERROR: dashboard IPC failed; restarting dashboard once"
    kill_dashboard
    sleep 0.2
    qs -p "$qs_dir" >>"$log_file" 2>&1 &
    sleep 0.7
    if ! call_ipc; then
        log "ERROR: dashboard IPC failed after restart; killing dashboard instance"
        kill_dashboard
        exit 1
    fi
fi
