#!/usr/bin/env bash

set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
    printf 'ERRORE: flatpak non disponibile sull host Bazzite.\n' >&2
    exit 1
fi

if ! flatpak list --app | grep -q 'org.openrgb.OpenRGB'; then
    flatpak install -y flathub org.openrgb.OpenRGB
fi

if [[ ! -f /etc/udev/rules.d/60-openrgb.rules ]]; then
    flatpak run org.openrgb.OpenRGB --generate-udev-rules |
        sudo tee /etc/udev/rules.d/60-openrgb.rules >/dev/null
fi

sudo modprobe i2c-dev
printf 'i2c-dev\n' | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx i2c; then
    sudo usermod -aG i2c "$USER"
    printf 'Utente aggiunto al gruppo i2c: riavvia la sessione per applicarlo.\n'
fi

sudo udevadm control --reload-rules
sudo udevadm trigger
printf 'OpenRGB e integrazione udev configurati per Bazzite.\n'
