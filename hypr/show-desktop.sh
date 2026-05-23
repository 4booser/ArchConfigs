#!/usr/bin/env bash
set -u

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-show-desktop-${HYPRLAND_INSTANCE_SIGNATURE:-default}.state"
TARGET_WORKSPACE="special:showdesktop"

if ! command -v jq >/dev/null 2>&1; then
    notify-send "show-desktop" "jq is required: sudo pacman -S jq" 2>/dev/null || true
    echo "show-desktop: jq is required. Install it with: sudo pacman -S jq" >&2
    exit 1
fi

lua_move_window() {
    local workspace="$1"
    local address="$2"
    local code

    code="$ (
        jq -Rn \
            --arg workspace "$workspace" \
            --arg window "address:$address" \
            '"hl.dispatch(hl.dsp.window.move({ workspace = " + ($workspace | @json) + ", follow = false, window = " + ($window | @json) + " }))"'
    )"

    # hyprland.lua configs parse `hyprctl dispatch` as Lua, so use eval with the Lua dispatcher API.
    hyprctl eval "$code" >/dev/null 2>&1 || true
}

# Restore windows if the state file exists.
if [[ -s "$STATE_FILE" ]]; then
    while IFS=$'\t' read -r address workspace; do
        [[ -n "${address:-}" && -n "${workspace:-}" ]] || continue
        lua_move_window "$workspace" "$address"
    done < "$STATE_FILE"

    rm -f "$STATE_FILE"
    exit 0
fi

active_workspace_id="$(hyprctl activeworkspace -j | jq -r '.id')"

hyprctl clients -j | jq -r --argjson workspace_id "$active_workspace_id" '
    .[]
    | select(.workspace.id == $workspace_id)
    | select(.mapped == true)
    | select((.pinned // false) == false)
    | [.address, (.workspace.name // (.workspace.id | tostring))]
    | @tsv
' > "$STATE_FILE"

if [[ ! -s "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    exit 0
fi

while IFS=$'\t' read -r address workspace; do
    [[ -n "${address:-}" ]] || continue
    lua_move_window "$TARGET_WORKSPACE" "$address"
done < "$STATE_FILE"
