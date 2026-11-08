#!/usr/bin/env bash

set -euo pipefail

target_path="${1:-${HF_HOME:-$HOME/.cache/huggingface}}"
target_path="${target_path%/}"
env_dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
env_file="$env_dir/10-huggingface.conf"

mkdir -p "$target_path" "$env_dir"
if [[ ! -w "$target_path" ]]; then
    printf 'ERRORE: directory non scrivibile: %s\n' "$target_path" >&2
    exit 1
fi

cat > "$env_file" <<EOF
# Configurazione ambiente Hugging Face per systemd user
HF_HOME=$target_path
HF_HUB_CACHE=$target_path/hub
TRANSFORMERS_CACHE=$target_path/hub
EOF

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment HF_HOME HF_HUB_CACHE TRANSFORMERS_CACHE 2>/dev/null || true
fi

printf 'Cache Hugging Face configurata in %s\n' "$target_path"
