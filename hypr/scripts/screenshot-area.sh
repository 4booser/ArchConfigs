#!/usr/bin/env bash

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

FILE="$DIR/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"

AREA=$(slurp)

# Если нажал Esc и отменил выбор
[ -z "$AREA" ] && exit 0

grim -g "$AREA" "$FILE"
wl-copy < "$FILE"
