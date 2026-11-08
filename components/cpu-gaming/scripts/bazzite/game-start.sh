#!/usr/bin/env bash

set -euo pipefail

CCD0="${CCD0:-0-5,12-17}"
CCD1="${CCD1:-6-11,18-23}"
USER_UID="${USER_UID:-$(id -u)}"
TASKSET_BIN="${TASKSET_BIN:-$(command -v taskset)}"

if [[ -z "$TASKSET_BIN" || ! -x "$TASKSET_BIN" ]]; then
    printf 'ERRORE: taskset non disponibile.\n' >&2
    exit 1
fi

mapfile -t audio_pids < <(
    pgrep -u "$USER_UID" -x -f 'kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects' || true
)
mapfile -t game_pids < <(
    pgrep -u "$USER_UID" -f 'wine|wine64|wineserver|pressure-vessel|gamescope|\.exe' || true
)
mapfile -t protected_pids < <(
    pgrep -u "$USER_UID" -f 'kwin_wayland|pipewire|pipewire-pulse|wireplumber|easyeffects|gamemoded|steam|steamwebhelper|wine|wine64|wineserver|pressure-vessel|gamescope|\.exe' || true
)

for pid in "${audio_pids[@]}" "${game_pids[@]}"; do
    [[ -n "$pid" ]] && "$TASKSET_BIN" -a -cp "$CCD0" "$pid" >/dev/null 2>&1 || true
done

mapfile -t all_user_pids < <(pgrep -u "$USER_UID" || true)
for pid in "${all_user_pids[@]}"; do
    [[ -z "$pid" || "$pid" == "$$" ]] && continue
    if ! printf '%s\n' "${protected_pids[@]}" | grep -qx "$pid"; then
        "$TASKSET_BIN" -a -cp "$CCD1" "$pid" >/dev/null 2>&1 || true
    fi
done
