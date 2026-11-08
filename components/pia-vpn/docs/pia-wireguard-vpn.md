# Private Internet Access (PIA) WireGuard con Port Forwarding e Watchdog

Guida all'integrazione nativa del tunnel VPN WireGuard per **Private Internet Access (PIA)** su **Bazzite / Fedora Atomic** (KDE Plasma), senza installare il client proprietario e preservando l'immutabilità del sistema operativo.

---

## 1. Modello Operativo e Architettura

L'architettura separa rigorosamente le responsabilità per garantire la massima stabilità e prevenire interruzioni inutili della connessione:

1. **Gestione Credenziali & Rinnovo Token (`pia-token-renew.timer`)**:
   - Ogni **12 ore** (e 5 minuti dopo il boot), un timer `systemd` invoca `renew-token.sh`.
   - Richiede un nuovo token di sessione PIA alle API REST e lo salva nella directory di stato configurata (`TOKEN_DIR`, predefinita `/opt/piavpn-manual`) con permessi restrittivi.
   - Non tocca il tunnel WireGuard già attivo: il token serve solo in fase di instaurazione della connessione.
2. **Demone Connessione & Watchdog (`pia-vpn.service`)**:
   - All'avvio, interroga le API PIA, genera chiavi WireGuard effimere e configura `/etc/wireguard/pia.conf` impostando i DNS privati PIA (`10.0.0.242`) per prevenire qualsiasi leak.
   - Si collega preferenzialmente alla regione **IT Milano (`italy`)** con supporto nativo a **Port Forwarding**, oppure calcola in tempo reale la latenza minima (ping) tra le regioni abilitate al PF.
   - Negozia il **Port Forwarding**, memorizza la firma crittografica per **riutilizzare la stessa porta fino a 2 mesi** e invia il keepalive (`bindPort`) ogni 15 minuti.
   - Un **watchdog interno** verifica ogni 30 secondi l'integrità dell'interfaccia `pia` e la raggiungibilità del gateway; in caso di caduta persistente (3 tentativi falliti), forza il riavvio del demone tramite `systemd`.
3. **Controllo Utente e Integrazione Desktop (`pia-ctl` e `pia-vpn.desktop`)**:
   - Comando CLI unificato `pia-ctl` per terminale e script.
   - Integrazione nativa in **KDE Plasma 6** con icona/scorciatoia desktop o pannello delle applicazioni: toggle con un click, notifiche desktop (`notify-send`) e menu contestuale con stato e porta attiva.

```text
+-------------------------------------------------------------------------------+
|                             PIA TOKEN MANAGER                                 |
| pia-token-renew.timer (ogni 12h) -> renew-token.sh -> /opt/piavpn-manual/token|
+---------------------------------------+---------------------------------------+
                                        | (Token valido 24h)
                                        v
+-------------------------------------------------------------------------------+
|                       WIREGUARD & PORT FORWARDING DEMON                        |
| pia-vpn.service -> pia-vpn.sh                                                 |
|  1. Risoluzione Server: IT Milano (italy) / Ping minimo con Port Forwarding   |
|  2. Handshake REST: Registrazione chiave effimera WireGuard (:1337/addKey)    |
|  3. Attivazione Tunnel: wg-quick up pia con DNS protetto 10.0.0.242           |
|  4. Port Forwarding: Firma persistente in pf_payload.json (stessa porta 60gg)|
|  5. Watchdog Loop: Ping ogni 30s + bindPort keepalive ogni 15 min             |
+---------------------------------------+---------------------------------------+
                                        |
                   +--------------------+--------------------+
                   v                                         v
+------------------------------------+   +------------------------------------+
|            CLI CONTROL             |   |        KDE PLASMA 6 DESKTOP        |
| ~/.local/bin/pia-ctl               |   | ~/.local/share/applications/       |
| {up | down | toggle | status | port}|   | pia-vpn.desktop (Panel / Launcher) |
+------------------------------------+   +------------------------------------+
```

---

## 2. Struttura dei File nella Repository

Tutti i componenti sono versionati all'interno della repository `handling-linux`:

```text
components/pia-vpn/
├── config/
│   └── pia-vpn.desktop              # Desktop entry per KDE Plasma
├── docs/
│   └── pia-wireguard-vpn.md         # Questa guida tecnica
├── scripts/
│   ├── install-services.sh
│   ├── pia-ctl
│   ├── pia-vpn.sh
│   └── renew-token.sh
└── systemd/
    ├── cachyos/
    └── bazzite/
```

Sul sistema, i file di stato e configurazione risiedono in:
- `/etc/pia/credentials`: credenziali e parametri di configurazione (modalità `0600`, root-only);
- `/opt/piavpn-manual/token`: token di autenticazione temporaneo (modalità `0600`);
- `/opt/piavpn-manual/pf_payload.json`: payload e firma del Port Forwarding per conservare la medesima porta;
- `/run/pia_port` e `/opt/piavpn-manual/active_port`: porta attualmente aperta per P2P/torrent (modalità `0644`).

---

## 3. Gestione e Persistenza del Port Forwarding

A differenza dei client commerciali che riassegnano una porta casuale ad ogni disconnessione:
1. L'API di PIA genera un `payload` (in formato JSON codificato Base64) associato a una `signature` crittografica emessa dal server.
2. Tale payload include il numero di porta e la data di scadenza (`expires_at`), normalmente valida per **60 giorni** (2 mesi).
3. `pia-vpn.sh` salva tale risposta nella directory di stato configurata. Ad ogni riconnessione, se mancano più di 24 ore alla scadenza, **invia la firma precedente**: PIA riassegna così la **stessa identica porta**.
4. Il demone esegue automaticamente la chiamata di keepalive (`bindPort`) ogni **15 minuti**, evitando la scadenza della mappatura da parte dei router di bordo di PIA.

---

## 4. Installazione e Configurazione

### 4.1. Configurazione Credenziali (`/etc/pia/credentials`)
Crea o aggiorna il file `/etc/pia/credentials`:

```bash
sudo mkdir -p /etc/pia
sudo chmod 700 /etc/pia
sudo nano /etc/pia/credentials
```

Inserisci:

```ini
PIA_USER=p1234567
PIA_PASS="la_tua_password_sicura"
PIA_REPO=/percorso/locale/manual-connections

# Opzioni avanzate (opzionali, valori predefiniti)
PREFERRED_REGION=italy
PIA_PF=true
PIA_DNS=true
```

Applica i permessi restrittivi:
```bash
sudo chmod 600 /etc/pia/credentials
```

---

### 4.2. Installazione Unità systemd
Copia le unità di sistema ed esegui il reload:

```bash
bash components/pia-vpn/scripts/install-services.sh
```

### 4.2.b. Variante Bazzite

Su Bazzite usa le unità in
[`systemd/bazzite/`](../systemd/bazzite/) e installa gli
script Bash PIA in un percorso persistente dell'host:

```bash
sudo install -d -m 755 /usr/local/libexec/handling-linux
sudo install -m 755 components/pia-vpn/scripts/pia-vpn.sh \
components/pia-vpn/scripts/renew-token.sh /usr/local/libexec/handling-linux/
sudo cp components/pia-vpn/systemd/bazzite/pia-* /etc/systemd/system/
sudo systemctl daemon-reload
```

Configura in `/etc/pia/credentials` almeno:

```ini
PIA_REPO=/var/home/utente/manual-connections
TOKEN_DIR=/var/lib/pia-handling
```

Verifica prima che il percorso del repository PIA sia leggibile dal servizio
root e che i contesti SELinux consentano le scritture previste. Se
`/usr/local/libexec` non è persistente nel deployment scelto, usa un percorso
host persistente equivalente e aggiorna `ExecStart` nelle unità.

Abilita il timer per il rinnovo automatico delle credenziali:
```bash
sudo systemctl enable --now pia-token-renew.timer
```

---

### 4.3. Regola Sudoers per il Controllo Desktop senza Password
Affinché il toggle dal pannello di KDE o tramite `pia-ctl` non richieda continuamente la password di root, configura una regola mirata in `sudoers.d`:

```bash
echo "simone ALL=(ALL) NOPASSWD: /usr/bin/systemctl start pia-vpn.service, /usr/bin/systemctl stop pia-vpn.service, /usr/bin/systemctl restart pia-vpn.service, /usr/bin/systemctl status pia-vpn.service, /usr/bin/wg show pia" | sudo tee /etc/sudoers.d/pia-vpn
sudo chmod 0440 /etc/sudoers.d/pia-vpn
```

---

### 4.4. Installazione Helper Utente e Desktop Entry
Copia lo script di controllo in `~/.local/bin/` e la desktop entry per KDE:

```bash
mkdir -p ~/.local/bin ~/.local/share/applications
cp components/pia-vpn/scripts/pia-ctl ~/.local/bin/pia-ctl
cp components/pia-vpn/pia-vpn.desktop ~/.local/share/applications/pia-vpn.desktop
chmod +x ~/.local/bin/pia-ctl
kbuildsycoca6 2>/dev/null || true
```

---

## 5. Utilizzo Quotidiano

### 5.1. Tramite Interfaccia Grafica (KDE Plasma)
- **Menu Applicazioni / KRunner**: Cerca **"PIA VPN"**.
- **Pannello delle Applicazioni (Taskbar)**: Fai clic destro sull'icona di PIA VPN nel menu delle applicazioni e seleziona **"Aggiungi al pannello"** o **"Aggiungi al desktop"**.
- **Click sinistro sul pulsante**: Alterna lo stato (Connette se disconnesso, Disconnette se attivo) mostrando una notifica di sistema con la porta assegnata.
- **Click destro**: Menu con azioni rapide:
  - *Connetti VPN*
  - *Disconnetti VPN*
  - *Visualizza Stato e Porta* (apre un dialog grafico con IP e porta).

### 5.2. Tramite Riga di Comando (`pia-ctl`)
```bash
# Connessione immediata
pia-ctl up

# Disconnessione
pia-ctl down

# Toggle rapido
pia-ctl toggle

# Visualizzazione stato completo (IP, server, porta, traffico RX/TX)
pia-ctl status

# Lettura della sola porta aperta (ideale per client torrent o script)
pia-ctl port
```

### 5.3. Avvio Automatico al Boot (Opzionale)
Se desideri che la VPN sia sempre attiva all'avvio del sistema senza dover premere alcun pulsante:
```bash
sudo systemctl enable pia-vpn.service
```
*(Potrai sempre disconnetterla manualmente all'occorrenza con `pia-ctl down` o dal pulsante KDE).*

---

## 6. Sicurezza e Particolarità Bazzite / SELinux

1. **SELinux in Enforcing Mode**:
   Su Bazzite, i servizi systemd che operano come root (`init_t`) non possono eseguire direttamente script utente con contesto `user_home_t`. Entrambi i file di servizio invocano `/usr/bin/bash` esplicitamente, garantendo piena conformità SELinux senza modifiche di contesto né policy permissive.
2. **Immutabilità OSTree e Symlink `/opt`**:
   In Bazzite `/opt` è un symlink a `var/opt`. Le sandbox di systemd (`ProtectSystem=strict`) includono esplicitamente `ReadWritePaths=/opt/piavpn-manual /var/opt/piavpn-manual /etc/wireguard /run` per prevenire errori di namespace di montaggio.
3. **Isolamento Credenziali**:
   I token temporanei e le firme non vengono mai registrati in chiaro nei log di `journalctl`, che registrano solo `PIA_TOKEN=[REDACTED]`.
4. **Parsing Sicuro delle Credenziali**:
   Lo script demone effettua un parsing dichiarativo riga per riga di `/etc/pia/credentials` senza ricorrere a `source` o `eval`. Questo evita che caratteri speciali (come `$` nelle password) attivino espansioni di parametro non volute in Bash quando è abilitato `set -u`.
