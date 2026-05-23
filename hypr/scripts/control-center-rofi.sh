#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

for dep in hyprctl jq rofi; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        notify-send "Control Center" "Missing dependency: $dep" 2>/dev/null || true
        echo "control-center: missing dependency: $dep" >&2
        exit 1
    fi
done

map_file="$(mktemp)"
menu_file="$(mktemp)"
trap 'rm -f "$map_file" "$menu_file"' EXIT

add_entry() {
    local label="$1"
    local action="$2"

    printf '%s\t%s\n' "$label" "$action" >> "$map_file"
    printf '%s\n' "$label" >> "$menu_file"
}

shorten() {
    local text="$1"
    local max="${2:-72}"

    text="${text//$'\n'/ }"
    text="${text//$'\t'/ }"

    if (( ${#text} > max )); then
        printf '%s…' "${text:0:max}"
    else
        printf '%s' "$text"
    fi
}

hypr_eval_focus_workspace() {
    local workspace="$1"
    local code

    code="$(jq -Rrn --arg workspace "$workspace" \
        '"hl.dispatch(hl.dsp.focus({ workspace = " + ($workspace | @json) + " }))"')"
    hyprctl eval "$code" >/dev/null 2>&1 || true
}

hypr_eval_focus_window() {
    local address="$1"
    local code

    code="$(jq -Rrn --arg window "address:$address" \
        '"hl.dispatch(hl.dsp.focus({ window = " + ($window | @json) + " }))"')"
    hyprctl eval "$code" >/dev/null 2>&1 || true
}

focus_window() {
    local address="$1"
    local workspace="$2"

    hypr_eval_focus_workspace "$workspace"
    sleep 0.05
    hypr_eval_focus_window "$address"
    pkill -RTMIN+8 waybar >/dev/null 2>&1 || true
}

add_entry "󰍹  Open windows" "noop"

index=0
while IFS=$'\t' read -r workspace address class title; do
    [[ -n "${address:-}" ]] || continue
    index=$((index + 1))

    class="$(shorten "${class:-unknown}" 20)"
    title="$(shorten "${title:-untitled}" 82)"

    add_entry "  󱂬  #$(printf '%02d' "$index")  ws:${workspace}  ${class}  —  ${title}" "window|${address}|${workspace}"
done < <(
    hyprctl clients -j | jq -r '
        sort_by(.workspace.id, .class, .title)
        | .[]
        | select((.mapped // true) == true)
        | [(.workspace.name // (.workspace.id | tostring)), .address, (.class // "unknown"), (.title // "untitled")]
        | @tsv
    '
)

if (( index == 0 )); then
    add_entry "  󰍹  No open windows" "noop"
fi

add_entry "" "noop"
add_entry "󰒓  Quick actions" "noop"
add_entry "    Kitty" "cmd|kitty"
add_entry "  󰉋  Nautilus" "cmd|nautilus"
add_entry "    Open ~/.config" "cmd|nautilus $HOME/.config"
add_entry "  󰋊  Screenshots folder" "cmd|nautilus $HOME/Pictures/Screenshots"
add_entry "    btop" "cmd|kitty --class btop-g -e btop"
add_entry "    Clipboard history" "cmd|cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy"
add_entry "  󰄀  Show desktop" "cmd|$HYPR_DIR/show-desktop.sh"
add_entry "  󰹑  Screenshot area" "cmd|$HYPR_DIR/scripts/screenshot-area.sh"
add_entry "  󰑓  Reload Hyprland + Waybar" "cmd|hyprctl reload; pkill waybar; setsid waybar >/dev/null 2>&1 &"
add_entry "    Lock" "cmd|hyprlock"
add_entry "    Power menu" "cmd|$HYPR_DIR/scripts/powermenu.sh"

choice="$(rofi \
    -dmenu \
    -i \
    -p "Control" \
    -matching fuzzy \
    -no-custom \
    -theme-str 'window { width: 860px; location: north; y-offset: 42px; border-radius: 18px; padding: 10px; background-color: rgba(12, 14, 20, 0.92); border: 1px; border-color: rgba(137, 180, 250, 0.35); }' \
    -theme-str 'mainbox { spacing: 8px; }' \
    -theme-str 'inputbar { padding: 10px 12px; border-radius: 12px; background-color: rgba(255, 255, 255, 0.06); }' \
    -theme-str 'prompt { text-color: #89b4fa; }' \
    -theme-str 'entry { placeholder: "search windows / actions"; text-color: #cdd6f4; }' \
    -theme-str 'listview { lines: 14; spacing: 4px; scrollbar: false; }' \
    -theme-str 'element { padding: 8px 10px; border-radius: 10px; }' \
    -theme-str 'element normal.normal { text-color: #cdd6f4; background-color: transparent; }' \
    -theme-str 'element selected.normal { text-color: #ffffff; background-color: rgba(137, 180, 250, 0.28); }' \
    -theme-str 'element-text { text-color: inherit; }' \
    < "$menu_file"
)" || exit 0

[[ -n "$choice" ]] || exit 0

action="$(awk -F '\t' -v selected="$choice" '$1 == selected { print $2; exit }' "$map_file")"
[[ -n "$action" ]] || exit 0

case "$action" in
    noop)
        exit 0
        ;;
    window\|*)
        IFS='|' read -r _ address workspace <<< "$action"
        focus_window "$address" "$workspace"
        ;;
    cmd\|*)
        command="${action#cmd|}"
        sh -c "$command" >/dev/null 2>&1 &
        ;;
esac
