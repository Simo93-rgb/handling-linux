#!/usr/bin/env bash

set -euo pipefail

expected_idle="${EXPECTED_ALL:-0-23}"
expected_game="${EXPECTED_CCD0:-0-5,12-17}"

check_processes() {
    local label="$1"
    local expected="$2"
    shift 2
    local found=0
    local pid mask
    for pattern in "$@"; do
        while read -r pid; do
            [[ -z "$pid" ]] && continue
            found=1
            mask="$(taskset -cp "$pid" 2>/dev/null | awk -F: '{gsub(/^ +| +$/, "", $2); print $2}')"
            if [[ "$mask" == "$expected" ]]; then
                printf '[OK] %s PID %s -> %s\n' "$label" "$pid" "$mask"
            else
                printf '[FAIL] %s PID %s -> %s (atteso %s)\n' "$label" "$pid" "$mask" "$expected"
                return 1
            fi
        done < <(pgrep -u "$(id -u)" -f "$pattern" || true)
    done
    (( found == 0 )) && printf '[--] %s non trovato\n' "$label"
}

if pgrep -u "$(id -u)" -f 'wine|wine64|wineserver|\.exe' >/dev/null; then
    check_processes "Game/Wine" "$expected_game" 'wine|wine64|wineserver|\.exe'
else
    check_processes "Desktop" "$expected_idle" 'kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects|plasmashell'
fi
