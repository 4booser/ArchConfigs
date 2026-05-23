#!/usr/bin/env bash

INFO=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)

if [ -z "$INFO" ]; then
    echo "󰝟 no audio"
    exit 0
fi

VOLUME=$(echo "$INFO" | awk '{print int($2 * 100)}')
MUTED=$(echo "$INFO" | grep -o "MUTED")

if [ "$MUTED" = "MUTED" ]; then
    echo " muted"
else
    if [ "$VOLUME" -ge 70 ]; then
        ICON=""
    elif [ "$VOLUME" -ge 30 ]; then
        ICON=""
    else
        ICON=""
    fi

    echo "$ICON $VOLUME%"
fi

