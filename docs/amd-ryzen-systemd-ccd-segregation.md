# AMD Ryzen Dual-CCD: Segregazione dinamica con GameMode

Guida per mantenere disponibili tutti i 24 thread durante desktop, compilazioni, shader e calcolo, applicando la segregazione dinamica (**Golden CCD 0 per il gioco/audio/compositor** e **CCD 1 per tutte le altre applicazioni**) solo mentre è attiva una sessione di gioco tramite `GameMode` su CachyOS / KDE Plasma 6.

---

## 1. Modello operativo

Il vecchio confinamento statico/permanente tramite override dei `.slice` di systemd non era ottimale: limitava a metà la CPU anche durante la compilazione del kernel (`make -j24`), la pre-compilazione degli shader Vulkan e i workload di calcolo, costringendo tutti i carichi su soli 12 thread.

La soluzione adottata è **completamente dinamica**:

1. **A riposo / Compilazioni / Uso generico**: Nessun vincolo di affinità. Tutti i processi hanno maschera `0-23` e possono utilizzare il 100% della CPU.
2. **Durante il gioco (`gamemoderun`)**:
   - `game-start.fish` sposta KWin Wayland, PipeWire, WirePlumber, EasyEffects e il gioco sul **CCD 0 (`0-5,12-17`)**;
   - `game-start.fish` sposta dinamicamente **tutti gli altri processi utente** (KDE Plasma, browser, Discord, client Steam, terminali, background apps) sul **CCD 1 (`6-11,18-23`)**;
   - I sotto-processi e i thread figli generati dalle applicazioni in background ereditano automaticamente la maschera CCD 1 dal processo genitore, evitando ogni intrusione nella cache L3 del CCD 0.
3. **Alla chiusura del gioco**:
   - `game-end.fish` ripristina istantaneamente la maschera `0-23` per KWin, per lo stack audio e per **tutti** i processi utente.

```text
+-------------------------------+-------------------------------+
| CCD 0: Gioco, Audio & KWin    | CCD 1: Desktop & Background   |
| 0-5,12-17                     | 6-11,18-23                   |
| KWin Wayland, PipeWire,       | Plasmashell, Browser, Discord,|
| WirePlumber, EasyEffects,     | Steam UI, client chat,        |
| Gioco Wine/Proton             | processi utente non-gaming    |
+-------------------------------+-------------------------------+
| Fuori dal gioco: TUTTI i processi tornano liberi su 0-23      |
| (100% potenza CPU per compilazione kernel make -j24)          |
+---------------------------------------------------------------+
```

Per un Ryzen 9 5900X, il Golden CCD 0 comprende i thread `0-5,12-17`, mentre il CCD 1 comprende `6-11,18-23`.

---

## 2. Rimozione dei vincoli statici precedenti

Se in precedenza erano stati configurati override statici nei file `.conf` di systemd, esegui lo script versionato per rimuovere i cpuset permanenti e mantenere solo la priorità real-time di KWin e dell'audio:

```fish
fish scripts/system/restore-standard-topology.fish
```

Lo script:

1. rimuove gli override `AllowedCPUs` da `system.slice`, `user.slice` e `app.slice`;
2. ricrea gli override di KWin, PipeWire, PipeWire Pulse e WirePlumber con `CPUSchedulingPolicy=rr` e priorità `50`, senza `AllowedCPUs`;
3. ricarica systemd e riavvia lo stack audio;
4. riporta immediatamente KWin alla maschera `0-23`.

Dopo l'esecuzione, il sistema è nello stato standard: compilazioni `make -j24`, shader Vulkan e workload pesanti possono utilizzare l'intera CPU.

---

## 3. Installazione e Sincronizzazione degli Script

Puoi sincronizzare e installare automaticamente tutti gli script con lo strumento dedicato:

```fish
fish scripts/system/sync-topology-scripts.fish
```

Lo script confronterà i file della repository con quelli in `~/.local/bin/` e `/etc/gamemode.ini`, chiedendo conferma per aggiornarli.

### Permessi per KWin Wayland (CAP_SYS_NICE)

In KDE Plasma 6, `kwin_wayland` opera con la capability Linux `CAP_SYS_NICE` per garantire priorità real-time al compositor. Affinché i comandi `taskset` eseguiti dagli hook utente di GameMode (`game-start.fish` e `game-end.fish`) possano modificare l'affinità di KWin senza richiedere password di root, assegna la capability a `taskset` una tantum:

```fish
sudo setcap cap_sys_nice+ep /usr/bin/taskset
```

### Configurazione `/etc/gamemode.ini`

Installa la configurazione versionata:

```fish
sudo cp config/gamemode.ini /etc/gamemode.ini
systemctl --user restart gamemoded
```

La sezione rilevante è:

```ini
[general]
reaper_freq=5
desiredgov=performance
igpu_power_threshold=-1

[cpu]
pin_cores=0-5,12-17
park_cores=no

[custom]
start=/home/simone/.local/bin/game-start.fish
end=/home/simone/.local/bin/game-end.fish
```

Gli hook vengono eseguiti solo quando il gioco è lanciato con `gamemoderun`, ad esempio nelle opzioni di avvio Steam:

```text
PROTON_ENABLE_NVAPI=1 DXVK_ENABLE_NVAPI=1 PROTON_ENABLE_NGX_UPDATER=1 PROTON_USE_EAC_LINUX=1 gamemoderun %command%
```


---

## 4. Verifica della Topologia

Esegui lo script diagnostico per verificare la segregazione:

```fish
fish scripts/tests/check_ccd_topology.fish
# oppure se copiato in ~/.local/bin:
# ~/.local/bin/check-topology.fish
```

### Risultati attesi:

1. **Durante il gioco (`gamemoderun` attivo)**:
   - `KWin Wayland Compositor`, `PipeWire Core Server`, `PipeWire Pulse Daemon`, `WirePlumber Session Mgr`, `EasyEffects DSP Daemon` e `Wine / Proton Game` -> **`0-5,12-17` (CCD 0)**.
   - `KDE Plasma Shell`, `Kate Text Editor`, `Dolphin File Manager`, `Web Browser`, `Chat` -> **`6-11,18-23` (CCD 1)**.
2. **Fuori dal gioco (sessione gaming chiusa / idle)**:
   - Tutti i processi (KWin, Audio, Plasma, Kate, Dolphin, Browser) riportano la maschera globale **`0-23`**.

Per il test diagnostico interno di GameMode:

```fish
gamemoded -t
```

Tutti i check critici devono restituire `Passed`.

