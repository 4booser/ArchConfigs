#!/usr/bin/env bash

SPECIAL_WS="special:minimized"

current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Проверяем, есть ли окна уже в special:minimized
hidden_windows=$(hyprctl clients -j | jq -r \
  --arg special "$SPECIAL_WS" \
  '.[] | select(.workspace.name == $special) | .address'
)

if [ -n "$hidden_windows" ]; then
    # Вернуть окна обратно на текущий рабочий стол
    echo "$hidden_windows" | while read -r addr; do
        hyprctl dispatch movetoworkspacesilent "$current_ws,address:$addr"
    done
else
    # Скрыть все окна с текущего рабочего стола
    hyprctl clients -j | jq -r \
      --argjson ws "$current_ws" \
      '.[] | select(.workspace.id == $ws) | select(.floating == false or .floating == true) | .address' \
    | while read -r addr; do
        hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$addr"
    done
fi
