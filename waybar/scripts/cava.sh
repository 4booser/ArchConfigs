#!/bin/bash

bar="▁▂▃▄▅▆▇█"

cava -p ~/.config/cava/waybar | while read -r line; do
    output=""

    IFS=';' read -ra values <<< "$line"

    for value in "${values[@]}"; do
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if (( value < 0 )); then value=0; fi
            if (( value > 7 )); then value=7; fi
            output+="${bar:$value:1}"
        fi
    done

    echo "$output"
done
