#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
HYPRPAPER_CONF="${HYPRPAPER_CONF:-$HOME/.config/hypr/hyprpaper.conf}"

if ! command -v walker >/dev/null 2>&1; then
  notify-send "Wallpaper" "walker не найден" 2>/dev/null || true
  exit 1
fi

mkdir -p "$WALLPAPER_DIR" "$(dirname "$HYPRPAPER_CONF")"

selection=$(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -printf '%f\n' | sort | walker --dmenu --placeholder "Wallpaper"
)

[ -n "${selection:-}" ] || exit 0
wallpaper="$WALLPAPER_DIR/$selection"

monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || hyprctl monitors | awk '/^Monitor / {print $2}')
{
  printf 'preload = %s\n' "$wallpaper"
  while IFS= read -r monitor; do
    [ -n "$monitor" ] && printf 'wallpaper = %s,%s\n' "$monitor" "$wallpaper"
  done <<< "$monitors"
  printf 'ipc = on\n'
} > "$HYPRPAPER_CONF"

if ! pgrep -x hyprpaper >/dev/null; then
  hyprpaper >/dev/null 2>&1 &
  sleep 0.2
fi

hyprctl hyprpaper unload all >/dev/null 2>&1 || true
hyprctl hyprpaper preload "$wallpaper" >/dev/null
while IFS= read -r monitor; do
  [ -n "$monitor" ] && hyprctl hyprpaper wallpaper "$monitor,$wallpaper" >/dev/null
 done <<< "$monitors"

notify-send "Wallpaper" "$selection" 2>/dev/null || true
