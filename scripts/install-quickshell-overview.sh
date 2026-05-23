#!/usr/bin/env bash
set -euo pipefail

module_repo="https://github.com/Shanu-Kumawat/quickshell-overview.git"
module_dir="$HOME/.config/quickshell/overview"
user_config="$module_dir/config.json"
backup=""

mkdir -p "$module_dir"

if [[ -f "$user_config" ]]; then
    backup="$(mktemp)"
    cp "$user_config" "$backup"
fi

if command -v yay >/dev/null 2>&1; then
    yay -S --needed quickshell quickshell-overview-git
elif command -v paru >/dev/null 2>&1; then
    paru -S --needed quickshell quickshell-overview-git
else
    echo "No yay/paru found. Falling back to git install into $module_dir"
fi

if [[ ! -f /etc/xdg/quickshell/overview/shell.qml && ! -f "$module_dir/shell.qml" ]]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth 1 "$module_repo" "$tmp/overview"
    rsync -a --exclude .git "$tmp/overview/" "$module_dir/"
fi

if [[ -n "$backup" && -f "$backup" ]]; then
    cp "$backup" "$user_config"
fi

if ! command -v qs >/dev/null 2>&1; then
    echo "qs command not found. Install quickshell first." >&2
    exit 1
fi

pkill -f 'qs.*-c overview' 2>/dev/null || true
qs -c overview >/dev/null 2>&1 &
sleep 0.5

if qs ipc -c overview call overview close >/dev/null 2>&1; then
    echo "Quickshell overview installed and IPC works. Use SUPER+T to toggle."
else
    echo "Overview files installed, but IPC test failed. Run: qs -c overview" >&2
fi
