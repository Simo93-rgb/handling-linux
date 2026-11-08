#!/usr/bin/env bash

set -euo pipefail

repo_root="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)}"
user_bin_dir="${USER_BIN_DIR:-$HOME/.local/bin}"
gamemode_config="${GAMEMODE_CONFIG:-$HOME/.config/gamemode.ini}"

install -d "$user_bin_dir" "$(dirname "$gamemode_config")"
install -m 755 "$repo_root/components/cpu-gaming/scripts/bazzite/game-start.sh" "$user_bin_dir/game-start.sh"
install -m 755 "$repo_root/components/cpu-gaming/scripts/bazzite/game-end.sh" "$user_bin_dir/game-end.sh"

cat > "$gamemode_config" <<EOF
[general]
reaper_freq=5
desiredgov=performance
igpu_power_threshold=-1

[cpu]
pin_cores=${CCD0:-0-5,12-17}
park_cores=no

[custom]
start=$user_bin_dir/game-start.sh
end=$user_bin_dir/game-end.sh
EOF

printf 'Hook GameMode Bazzite installati in %s\n' "$user_bin_dir"
printf 'Configurazione GameMode generata in %s\n' "$gamemode_config"
