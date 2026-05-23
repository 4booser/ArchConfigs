#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_UI="$SCRIPT_DIR/control-center.py"
FALLBACK="$SCRIPT_DIR/control-center-rofi.sh"

if command -v python >/dev/null 2>&1 && python - <<'PY' >/dev/null 2>&1
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
PY
then
    exec python "$PY_UI"
fi

notify-send "Control Center" "GTK UI dependencies are missing. Using fallback." 2>/dev/null || true
exec "$FALLBACK"
