#!/usr/bin/env bash

set -euo pipefail

ALL_CORES="${ALL_CORES:-0-23}"
USER_UID="${USER_UID:-$(id -u)}"
TASKSET_BIN="${TASKSET_BIN:-$(command -v taskset)}"

if [[ -z "$TASKSET_BIN" || ! -x "$TASKSET_BIN" ]]; then
    printf 'ERRORE: taskset non disponibile.\n' >&2
    exit 1
fi

mapfile -t user_pids < <(pgrep -u "$USER_UID" || true)
for pid in "${user_pids[@]}"; do
    [[ -n "$pid" && "$pid" != "$$" ]] &&
        "$TASKSET_BIN" -a -cp "$ALL_CORES" "$pid" >/dev/null 2>&1 || true
done
