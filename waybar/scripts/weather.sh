#!/usr/bin/env bash
set -u

CITY="Kyiv"

weather="$(curl -fsS --max-time 5 "https://wttr.in/${CITY}?format=%c+%t" 2>/dev/null || true)"

if [[ -z "$weather" ]]; then
    jq -cn '{text: "󰖪 weather"}'
else
    jq -cn --arg text "$weather" '{text: $text}'
fi
