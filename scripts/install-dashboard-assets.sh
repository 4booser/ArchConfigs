#!/usr/bin/env bash
set -euo pipefail

asset_dir="$HOME/.config/quickshell/dashboard/assets"
mkdir -p "$asset_dir"

bongo_url="https://raw.githubusercontent.com/mahiiverse1/mahiiverse1/main/bongo-cat.gif"
bongo_file="$asset_dir/bongo-cat.gif"

if [[ ! -s "$bongo_file" ]]; then
    if command -v curl >/dev/null 2>&1; then
        curl -fL "$bongo_url" -o "$bongo_file"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$bongo_file" "$bongo_url"
    else
        echo "curl or wget is required to download bongo-cat.gif" >&2
        exit 1
    fi
fi

chmod 644 "$bongo_file"
echo "Dashboard assets installed: $bongo_file"
