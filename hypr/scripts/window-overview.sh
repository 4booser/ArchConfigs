#!/usr/bin/env bash
set -euo pipefail

DIR="${BASH_SOURCE[0]}"
DIR="$(dirname "$DIR")"
"$DIR/control-center-rofi.sh"
