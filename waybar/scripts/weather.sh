#!/usr/bin/env bash

CITY="Kyiv"

weather=$(curl -s "https://wttr.in/${CITY}?format=%c+%t")

if [ -z "$weather" ]; then
    echo '{"text":"󰖪 weather"}'
else
    echo "{\"text\":\"${weather}\"}"
fi
