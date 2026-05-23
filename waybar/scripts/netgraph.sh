#!/usr/bin/env bash

IFACE="enp2s0"

STATE_FILE="/tmp/waybar-netgraph-${IFACE}.state"
HISTORY_FILE="/tmp/waybar-netgraph-${IFACE}.history"

BARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
WIDTH=16

RX_FILE="/sys/class/net/$IFACE/statistics/rx_bytes"
TX_FILE="/sys/class/net/$IFACE/statistics/tx_bytes"

if [ ! -f "$RX_FILE" ] || [ ! -f "$TX_FILE" ]; then
    echo "󰖪 ────────────────"
    exit 0
fi

RX=$(cat "$RX_FILE")
TX=$(cat "$TX_FILE")
IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)

[ -z "$IP" ] && IP="no ip"

if [ -f "$STATE_FILE" ]; then
    read OLD_RX OLD_TX < "$STATE_FILE"
    DOWN=$((RX - OLD_RX))
    UP=$((TX - OLD_TX))
else
    DOWN=0
    UP=0
fi

echo "$RX $TX" > "$STATE_FILE"

TOTAL=$((DOWN + UP))

# Ограничитель масштаба.
# Чем меньше число, тем активнее график.
SCALE=131072

LEVEL=$((TOTAL / SCALE))

if [ "$LEVEL" -gt 7 ]; then
    LEVEL=7
fi

BAR="${BARS[$LEVEL]}"

OLD_HISTORY=""
[ -f "$HISTORY_FILE" ] && OLD_HISTORY=$(cat "$HISTORY_FILE")

NEW_HISTORY="${OLD_HISTORY}${BAR}"
NEW_HISTORY=$(echo "$NEW_HISTORY" | grep -o ".\{$WIDTH\}$")

# Если истории ещё мало, добиваем слева пустыми столбиками
LEN=${#NEW_HISTORY}
while [ "$LEN" -lt "$WIDTH" ]; do
    NEW_HISTORY="▁${NEW_HISTORY}"
    LEN=${#NEW_HISTORY}
done

echo "$NEW_HISTORY" > "$HISTORY_FILE"

format_speed() {
    local BYTES=$1

    if [ "$BYTES" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1f MB/s\", $BYTES / 1048576}"
    elif [ "$BYTES" -ge 1024 ]; then
        awk "BEGIN {printf \"%.0f KB/s\", $BYTES / 1024}"
    else
        echo "${BYTES} B/s"
    fi
}

DOWN_H=$(format_speed "$DOWN")
UP_H=$(format_speed "$UP")

echo "{\"text\":\"󰈀 ${NEW_HISTORY}\", \"tooltip\":\"${IFACE}\\nIP: ${IP}\\nDown: ${DOWN_H}\\nUp: ${UP_H}\"}"
