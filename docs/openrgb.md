# Configurazione e Risoluzione Problemi OpenRGB (Flatpak) su CachyOS / Arch Linux

Guida tecnica per l'installazione, la configurazione dei permessi hardware (`udev`) e l'esclusione di periferiche con payload HID incompatibili (es. Epomaker TH96).

---

## 1. Installazione via Flatpak

Installazione del client OpenRGB tramite Flathub:

```bash
flatpak install flathub org.openrgb.OpenRGB
```

> **Nota architetturale:** Trattandosi di un'applicazione containerizzata via Flatpak, OpenRGB non possiede i privilegi né l'accesso in scrittura a `/etc/udev/rules.d/` sull'host. Le regole di accesso ai nodi `/dev/i2c-*`, `/dev/hidraw*` e ai controller USB/SMBus devono essere configurate manualmente a livello host.

---

## 2. Configurazione delle Regole Udev

Per consentire l'accesso hardware non-root ai controller RGB, è necessario installare il file di regole `60-openrgb.rules`. Di seguito sono riportate le 3 modalità disponibili:

### Opzione 1: Installazione da Package Manager / AUR (Consigliata)
Su CachyOS/Arch Linux è disponibile il pacchetto standalone gestito dal package manager, che non introduce dipendenze binarie complete:

```fish
paru -S openrgb-udev-rules
# oppure:
yay -S openrgb-udev-rules
```

### Opzione 2: Download Diretto dal Repository Ufficiale (GitLab Upstream)
Scaricare il file canonical aggiornato direttamente dal repository upstream di OpenRGB:

```fish
sudo curl -Lo /etc/udev/rules.d/60-openrgb.rules https://gitlab.com/CalcProgrammer1/OpenRGB/-/raw/master/60-openrgb.rules
```

### Opzione 3: Generazione Automatica da CLI Flatpak
OpenRGB integra una flag interna per stampare sullo standard output le definizioni udev esatte allineate alla versione in esecuzione:

```fish
flatpak run org.openrgb.OpenRGB --generate-udev-rules | sudo tee /etc/udev/rules.d/60-openrgb.rules > /dev/null
```

---

## 3. Configurazione Moduli Kernel, Gruppi Utente e Ricarica Udev

1. **Aggiunta al gruppo I2C:**
   ```fish
   sudo usermod -aG i2c $USER
   ```

2. **Caricamento modulo kernel I2C (SMBus / DRAM / Motherboard):**
   ```fish
   sudo modprobe i2c-dev
   echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf
   ```

3. **Ricarica e trigger del sottosistema udev:**
   ```fish
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

---

## 4. Esclusione Periferiche Incompatibili (Epomaker TH96)

La tastiera Epomaker TH96 viene rilevata da un detector generico (es. *Epomaker Keyboard* o *Sinowealth Device*), ma i payload HID non sono supportati correttamente, causando anomalie o blocchi. È possibile disattivare la scansione tramite due metodi.

### Metodo 1: Disattivazione via GUI
1. Aprire **OpenRGB**.
2. Andare nella scheda **Settings** -> sotto-sezione **Supported Devices** (Detectors).
3. Deselezionare i controller dedicati:
   - `Epomaker Keyboard`
   - `Sinowealth Device` / `Sonix Keyboard`
4. Cliccare su **Save Settings** e riavviare l'applicazione.

### Metodo 2: Modifica Manuale Configurazione JSON (Flatpak)
A OpenRGB chiuso, modificare il file di configurazione nella sandbox Flatpak:

* **Path:** `~/.var/app/org.openrgb.OpenRGB/config/OpenRGB/OpenRGB.json`

Inserire o aggiornare la sezione `"detectors"`:

```json
{
  "detectors": {
    "Epomaker Keyboard": false,
    "Sinowealth Device": false,
    "Sonix Keyboard": false
  }
}
```

---

## 5. Gestione Illuminazione Onboard (Epomaker TH96)

* **`Fn + \`**: Cicla gli effetti e le animazioni onboard.
* **`Fn + Backspace`**: Attiva / Disattiva l'illuminazione LED.
* **`Fn + P`**: Cambia il colore dell'effetto corrente.
* **`Fn + ↑ / ↓`**: Aumenta / Diminuisce la luminosità.
* **`Fn + ← / →`**: Modifica la velocità dell'effetto dinamico.

## 6. Script di automazione
Il file [openrgb_setup.sh](../scripts/config/openrgb_setup.sh) automatizza tutto il processo con la generazione delle regole `udev` tramite *flatpak* e l'esclusione della tastiera Epomaker TH96 tramite file `json`. 