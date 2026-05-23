#!/usr/bin/env bash
set -euo pipefail

notify-send "Window Overview" "Нормальный overview будет сделан отдельно. Rofi fallback отключён." 2>/dev/null || true
exit 0
