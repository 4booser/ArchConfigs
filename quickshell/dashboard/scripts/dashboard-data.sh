#!/usr/bin/env bash
set -u

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/qs-dashboard"
mkdir -p "$cache_dir"
weather_cache="$cache_dir/weather-kyiv.json"
net_state="$cache_dir/net-state"

run() {
  timeout 0.8s "$@" 2>/dev/null || true
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null || printf '""'
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
  media_title="$(run playerctl metadata title)"
  media_artist="$(run playerctl metadata artist)"
  media_album="$(run playerctl metadata album)"
  media_status="$(run playerctl status)"
  media_art="$(run playerctl metadata mpris:artUrl)"
  media_player="$(run playerctl metadata --format '{{playerName}}')"
fi
[[ -n "$media_status" ]] || media_status="Stopped"

sink_id=""
app_volume=100
if cmd_exists wpctl; then
  vol_line="$(run wpctl get-volume @DEFAULT_AUDIO_SINK@)"
  vol_num="$(awk '{ for (i=1; i<=NF; i++) if ($i ~ /^[0-9.]+$/) print int($i * 100) }' <<< "$vol_line" | head -n1)"
  [[ -n "${vol_num:-}" ]] && app_volume="$vol_num"
fi

weather_json="{}"
weather_url='https://api.open-meteo.com/v1/forecast?latitude=50.4501&longitude=30.5234&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean,wind_speed_10m_max,sunrise,sunset&timezone=Europe%2FKyiv&forecast_days=7'

weather_needs_update=1
if [[ -s "$weather_cache" ]]; then
  now_ts="$(date +%s)"
  file_ts="$(stat -c %Y "$weather_cache" 2>/dev/null || echo 0)"
  age=$((now_ts - file_ts))
  if (( age < 1800 )); then
    weather_needs_update=0
  fi
fi

if (( weather_needs_update == 1 )) && cmd_exists curl; then
  tmp="$weather_cache.tmp"
  if timeout 2.5s curl -fsSL --connect-timeout 1.5 --max-time 2.5 "$weather_url" > "$tmp" 2>/dev/null; then
    if python3 -m json.tool "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$weather_cache"
    else
      rm -f "$tmp"
    fi
  fi
fi

if [[ -s "$weather_cache" ]]; then
  weather_json="$(cat "$weather_cache" 2>/dev/null || printf '{}')"
fi

case "$weather_json" in
  \{*) ;;
  *) weather_json="{}" ;;
esac

cpu_usage=0
if [[ -r /proc/stat ]]; then
  read -r _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ < /proc/stat
  idle1=$((i1 + iw1))
  total1=$((u1 + n1 + s1 + i1 + iw1 + irq1 + sirq1 + st1))
  sleep 0.05
  read -r _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ < /proc/stat
  idle2=$((i2 + iw2))
  total2=$((u2 + n2 + s2 + i2 + iw2 + irq2 + sirq2 + st2))
  diff_idle=$((idle2 - idle1))
  diff_total=$((total2 - total1))
  if (( diff_total > 0 )); then
    cpu_usage=$((100 * (diff_total - diff_idle) / diff_total))
  fi
fi

cpu_temp=0
for temp in /sys/class/thermal/thermal_zone*/temp; do
  [[ -r "$temp" ]] || continue
  v="$(cat "$temp" 2>/dev/null || echo 0)"
  [[ "$v" =~ ^[0-9]+$ ]] || continue
  v=$((v / 1000))
  if (( v >= 20 && v <= 120 && v > cpu_temp )); then
    cpu_temp="$v"
  fi
done

gpu_usage=0
gpu_temp=0
if cmd_exists nvidia-smi; then
  gpu_line="$(timeout 0.8s nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
  if [[ -n "$gpu_line" ]]; then
    gpu_usage="$(cut -d, -f1 <<< "$gpu_line" | tr -d ' ')"
    gpu_temp="$(cut -d, -f2 <<< "$gpu_line" | tr -d ' ')"
  fi
fi
[[ "$gpu_usage" =~ ^[0-9]+$ ]] || gpu_usage=0
[[ "$gpu_temp" =~ ^[0-9]+$ ]] || gpu_temp=0

read -r mem_total mem_avail < <(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t+0, a+0}' /proc/meminfo)
if (( mem_total > 0 )); then
  ram_usage=$((100 * (mem_total - mem_avail) / mem_total))
else
  ram_usage=0
fi
ram_used_gb="$(awk -v t="$mem_total" -v a="$mem_avail" 'BEGIN { printf "%.1f", (t-a)/1024/1024 }')"
ram_total_gb="$(awk -v t="$mem_total" 'BEGIN { printf "%.1f", t/1024/1024 }')"

disk_line="$(df -h / 2>/dev/null | awk 'NR==2 {print $3, $2, $5}')"
disk_used="$(awk '{print $1}' <<< "$disk_line")"
disk_total="$(awk '{print $2}' <<< "$disk_line")"
disk_usage="$(awk '{gsub(/%/,"",$3); print $3+0}' <<< "$disk_line")"
[[ -n "$disk_used" ]] || disk_used="0"
[[ -n "$disk_total" ]] || disk_total="0"

rx=0
tx=0
if [[ -r /proc/net/dev ]]; then
  while IFS=: read -r iface rest; do
    iface="$(xargs <<< "$iface")"
    [[ "$iface" == "lo" || -z "$rest" ]] && continue
    set -- $rest
    rx=$((rx + ${1:-0}))
    tx=$((tx + ${9:-0}))
  done < /proc/net/dev
fi

now="$(date +%s)"
net_down=0
net_up=0
if [[ -s "$net_state" ]]; then
  read -r old_rx old_tx old_time < "$net_state" || true
  old_rx=${old_rx:-$rx}
  old_tx=${old_tx:-$tx}
  old_time=${old_time:-$now}
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
(( net_graph > 100 )) && net_graph=100
(( net_graph < 0 )) && net_graph=0

ip_addr="$(timeout 0.5s ip -4 addr show scope global 2>/dev/null | awk '/inet / {print $2 " " $NF; exit}')"

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
    "cpuTemp": $cpu_temp,
    "gpu": $gpu_usage,
    "gpuTemp": $gpu_temp,
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
