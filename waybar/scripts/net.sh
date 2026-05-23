#!/usr/bin/env bash

IFACE="enp2s0"
STATE_FILE="/tmp/waybar-net-${IFACE}"

RX=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null)
TX=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null)
IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)

if [ -z "$RX" ] || [ -z "$TX" ]; then
    echo "󰖪 no net"
    exit 0
fi

if [ -z "$IP" ]; then
    IP="no ip"
fi

if [ -f "$STATE_FILE" ]; then
    read OLD_RX OLD_TX < "$STATE_FILE"

    DOWN=$((RX - OLD_RX))
    UP=$((TX - OLD_TX))
else
    DOWN=0
    UP=0
fi

echo "$RX $TX" > "$STATE_FILE"

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

echo "󰈀 $IFACE $IP  ↓ $DOWN_H  ↑ $UP_H"
