#!/usr/bin/env bash

target="$1"
active="$(hyprctl activeworkspace -j | jq -r '.id')"

if [ "$active" = "$target" ]; then
    printf '{"text":"%s","class":"active"}\n' "$target"
else
    printf '{"text":"%s","class":"inactive"}\n' "$target"
fi
