#!/usr/bin/env bash
set -euo pipefail

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/qs-dashboard"
mkdir -p "$cache_dir"
weather_cache="$cache_dir/weather-kyiv.json"
net_state="$cache_dir/net-state"

json_escape() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

media_title=""
media_artist=""
media_album=""
media_status="Stopped"
media_art=""
media_player=""

if cmd_exists playerctl; then
  media_title="$(playerctl metadata title 2>/dev/null || true)"
  media_artist="$(playerctl metadata artist 2>/dev/null || true)"
  media_album="$(playerctl metadata album 2>/dev/null || true)"
  media_status="$(playerctl status 2>/dev/null || echo Stopped)"
  media_art="$(playerctl metadata mpris:artUrl 2>/dev/null || true)"
  media_player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || true)"
fi

sink_id=""
app_volume=100
if cmd_exists pactl; then
  sink_json="$(pactl list sink-inputs 2>/dev/null | python - "$media_player" <<'PY' || true
import re, sys
player = (sys.argv[1] if len(sys.argv) > 1 else '').lower()
raw = sys.stdin.read()
best = None
for block in raw.split('Sink Input #')[1:]:
    sid = block.splitlines()[0].strip()
    vol = re.search(r'Volume:.*?(\d+)%', block)
    text = block.lower()
    item = (sid, int(vol.group(1)) if vol else 100)
    if player and player in text:
        best = item
        break
    if best is None and vol:
        best = item
if best:
    print(f'{best[0]} {best[1]}')
PY
)"
  if [[ -n "${sink_json:-}" ]]; then
    sink_id="${sink_json%% *}"
    app_volume="${sink_json##* }"
  fi
fi

weather_json="{}"
weather_url='https://api.open-meteo.com/v1/forecast?latitude=50.4501&longitude=30.5234&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,wind_speed_10m_max,sunrise,sunset&timezone=Europe%2FKyiv&forecast_days=7'
if cmd_exists curl && cmd_exists jq; then
  if curl -fsSL --connect-timeout 3 --max-time 6 "$weather_url" > "$weather_cache.tmp"; then
    mv "$weather_cache.tmp" "$weather_cache"
  fi
fi
if [[ -s "$weather_cache" ]]; then
  weather_json="$(cat "$weather_cache")"
fi

cpu_usage="0"
if [[ -r /proc/stat ]]; then
  read -r _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ < /proc/stat
  idle1=$((i1 + iw1))
  total1=$((u1 + n1 + s1 + i1 + iw1 + irq1 + sirq1 + st1))
  sleep 0.08
  read -r _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ < /proc/stat
  idle2=$((i2 + iw2))
  total2=$((u2 + n2 + s2 + i2 + iw2 + irq2 + sirq2 + st2))
  diff_idle=$((idle2 - idle1))
  diff_total=$((total2 - total1))
  if (( diff_total > 0 )); then
    cpu_usage=$((100 * (diff_total - diff_idle) / diff_total))
  fi
fi

cpu_temp=""
for temp in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "$temp" ]] || continue
  v="$(cat "$temp" 2>/dev/null || echo 0)"
  v=$((v / 1000))
  if (( v >= 20 && v <= 120 )); then
    if [[ -z "$cpu_temp" || "$v" -gt "$cpu_temp" ]]; then cpu_temp="$v"; fi
  fi
done

gpu_usage="0"
gpu_temp=""
if cmd_exists nvidia-smi; then
  gpu_line="$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
  if [[ -n "$gpu_line" ]]; then
    gpu_usage="$(cut -d, -f1 <<< "$gpu_line" | tr -d ' ')"
    gpu_temp="$(cut -d, -f2 <<< "$gpu_line" | tr -d ' ')"
  fi
elif cmd_exists radeontop; then
  gpu_usage="0"
fi

read -r mem_total mem_avail < <(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
ram_usage=$((100 * (mem_total - mem_avail) / mem_total))
ram_used_gb="$(awk -v t="$mem_total" -v a="$mem_avail" 'BEGIN { printf "%.1f", (t-a)/1024/1024 }')"
ram_total_gb="$(awk -v t="$mem_total" 'BEGIN { printf "%.1f", t/1024/1024 }')"

disk_line="$(df -h / | awk 'NR==2 {print $3, $2, $5}')"
disk_used="$(awk '{print $1}' <<< "$disk_line")"
disk_total="$(awk '{print $2}' <<< "$disk_line")"
disk_usage="$(awk '{gsub(/%/,"",$3); print $3}' <<< "$disk_line")"

rx=0; tx=0
while IFS=: read -r iface rest; do
  iface="$(xargs <<< "$iface")"
  [[ "$iface" == "lo" || -z "$rest" ]] && continue
  set -- $rest
  rx=$((rx + $1))
  tx=$((tx + $9))
done < /proc/net/dev
now="$(date +%s)"
net_down=0; net_up=0
if [[ -s "$net_state" ]]; then
  read -r old_rx old_tx old_time < "$net_state" || true
  dt=$((now - old_time))
  if (( dt > 0 )); then
    net_down=$(((rx - old_rx) / dt))
    net_up=$(((tx - old_tx) / dt))
  fi
fi
printf '%s %s %s\n' "$rx" "$tx" "$now" > "$net_state"
net_down_kib=$((net_down / 1024))
net_up_kib=$((net_up / 1024))
net_graph=$(((net_down_kib + net_up_kib) / 50))
if (( net_graph > 100 )); then net_graph=100; fi

ip_addr="$(ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2 " " $NF; exit}')"

cat <<JSON
{
  "media": {
    "title": $(printf '%s' "$media_title" | json_escape),
    "artist": $(printf '%s' "$media_artist" | json_escape),
    "album": $(printf '%s' "$media_album" | json_escape),
    "status": $(printf '%s' "$media_status" | json_escape),
    "art": $(printf '%s' "$media_art" | json_escape),
    "player": $(printf '%s' "$media_player" | json_escape),
    "sinkId": $(printf '%s' "$sink_id" | json_escape),
    "volume": $app_volume
  },
  "system": {
    "cpu": $cpu_usage,
    "cpuTemp": ${cpu_temp:-0},
    "gpu": $gpu_usage,
    "gpuTemp": ${gpu_temp:-0},
    "ram": $ram_usage,
    "ramUsed": "$ram_used_gb",
    "ramTotal": "$ram_total_gb",
    "disk": $disk_usage,
    "diskUsed": "$disk_used",
    "diskTotal": "$disk_total",
    "netDown": $net_down_kib,
    "netUp": $net_up_kib,
    "netGraph": $net_graph,
    "ip": $(printf '%s' "$ip_addr" | json_escape)
  },
  "weather": $weather_json
}
JSON
