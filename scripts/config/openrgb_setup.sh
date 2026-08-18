#!/usr/bin/env fish
# ==============================================================================
# Setup & Gestione OpenRGB (Flatpak) per CachyOS / Arch Linux
# ==============================================================================

function echo_step -a message
    set_color cyan; echo "==> $message"; set_color normal
end

function echo_ok -a message
    set_color green; echo "  [OK] $message"; set_color normal
end

function echo_warn -a message
    set_color yellow; echo "  [WARN] $message"; set_color normal
end

# 1. Verifica/Installazione Flatpak
echo_step "Verifica installazione Flatpak di OpenRGB..."
if not flatpak list --app | string match -q "*org.openrgb.OpenRGB*"
    echo_warn "OpenRGB Flatpak non trovato. Installazione in corso..."
    flatpak install -y flathub org.openrgb.OpenRGB
else
    echo_ok "OpenRGB Flatpak è già installato."
end

# 2. Configurazione Udev Rules (Opzione 3: generazione tramite CLI Flatpak)
echo_step "Configurazione regole Udev..."
if not test -f /etc/udev/rules.d/60-openrgb.rules
    echo_warn "Regole udev assenti. Generazione tramite Flatpak CLI..."
    flatpak run org.openrgb.OpenRGB --generate-udev-rules | sudo tee /etc/udev/rules.d/60-openrgb.rules > /dev/null
    echo_ok "File /etc/udev/rules.d/60-openrgb.rules creato."
else
    echo_ok "Regole udev già presenti in /etc/udev/rules.d/60-openrgb.rules."
end

# 3. Configurazione modulo i2c-dev (DRAM / SMBus / Scheda Madre)
echo_step "Configurazione modulo kernel i2c-dev..."
if not lsmod | string match -q "i2c_dev"
    sudo modprobe i2c-dev
    echo_ok "Modulo i2c-dev caricato."
else
    echo_ok "Modulo i2c-dev già caricato."
end

if not test -f /etc/modules-load.d/i2c-dev.conf
    echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf > /dev/null
    echo_ok "Persistenza modulo i2c-dev salvata in /etc/modules-load.d/i2c-dev.conf."
end

# 4. Assegnazione gruppo i2c
echo_step "Verifica appartenenza gruppo i2c per utente '$USER'..."
if not id -nG "$USER" | string match -q "*i2c*"
    sudo usermod -aG i2c $USER
    echo_warn "Utente aggiunto al gruppo 'i2c'. Riavvia la sessione o esegui 'newgrp i2c' per applicare."
else
    echo_ok "L'utente '$USER' appartiene già al gruppo 'i2c'."
end

# 5. Reload del sottosistema udev
echo_step "Ricarica del sottosistema udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger
echo_ok "Udev ricaricato ed eventi hardware scatenati."

# 6. Esclusione automatica detector TH96 (Epomaker / Sinowealth / Sonix) - Opzione 2: modifica manuale JSON
 echo_step "Configurazione esclusione detector per Epomaker TH96..."
set CONFIG_DIR "$HOME/.var/app/org.openrgb.OpenRGB/config/OpenRGB"
set CONFIG_FILE "$CONFIG_DIR/OpenRGB.json"

mkdir -p "$CONFIG_DIR"

if test -f "$CONFIG_FILE"
    if command -v jq > /dev/null
        set TMP_JSON (mktemp)
        jq '.detectors = (.detectors // {}) | .detectors["Epomaker Keyboard"] = false | .detectors["Sinowealth Device"] = false | .detectors["Sonix Keyboard"] = false' "$CONFIG_FILE" > "$TMP_JSON"
        mv "$TMP_JSON" "$CONFIG_FILE"
        echo_ok "Configurazione aggiornata tramite jq in $CONFIG_FILE."
    else
        python3 -c "
import json
path = '$CONFIG_FILE'
try:
    with open(path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}
detectors = data.get('detectors', {})
detectors['Epomaker Keyboard'] = False
detectors['Sinowealth Device'] = False
detectors['Sonix Keyboard'] = False
data['detectors'] = detectors
with open(path, 'w') as f:
    json.dump(data, f, indent=4)
"
        echo_ok "Configurazione aggiornata tramite fallback Python in $CONFIG_FILE."
    end
else
    echo '{
    "detectors": {
        "Epomaker Keyboard": false,
        "Sinowealth Device": false,
        "Sonix Keyboard": false
    }
}' > "$CONFIG_FILE"
    echo_ok "Struttura di configurazione creata con detector disabilitati: $CONFIG_FILE."
end

echo_step "Procedura completata. Puoi avviare OpenRGB senza conflitti HID."