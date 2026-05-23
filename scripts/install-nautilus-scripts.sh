#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_dir/nautilus/scripts"
target_dir="$HOME/.local/share/nautilus/scripts"

mkdir -p "$target_dir"

if [[ ! -d "$source_dir" ]]; then
    echo "install-nautilus-scripts: source directory not found: $source_dir" >&2
    exit 1
fi

find "$source_dir" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' script; do
    name="$(basename "$script")"
    ln -sf "$script" "$target_dir/$name"
    chmod +x "$script"
    chmod +x "$target_dir/$name"
    echo "installed: $target_dir/$name -> $script"
done

if command -v nautilus >/dev/null 2>&1; then
    nautilus -q >/dev/null 2>&1 || true
fi
