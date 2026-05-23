#!/bin/bash

if command -v nvidia-smi >/dev/null 2>&1; then
    usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1)
    temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n 1)
    echo "󰢮  ${usage}% ${temp}°C"
else
    echo "󰢮  N/A"
fi
