#!/usr/bin/env bash

set -euo pipefail

repo_root="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)}"
install_dir="${PIA_INSTALL_DIR:-/usr/local/libexec/handling-linux}"

sudo install -d -m 755 "$install_dir"
sudo install -m 755 \
    "$repo_root/components/pia-vpn/scripts/pia-vpn.sh" \
    "$repo_root/components/pia-vpn/scripts/renew-token.sh" \
    "$install_dir/"
sudo install -m 644 "$repo_root/components/pia-vpn/systemd/cachyos/pia-"*.service \
    "$repo_root/components/pia-vpn/systemd/cachyos/pia-"*.timer /etc/systemd/system/
sudo systemctl daemon-reload

printf 'Servizi PIA installati in %s\n' "$install_dir"
